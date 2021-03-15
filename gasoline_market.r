library(rethinking)
root <- "C:\\Users\\tenni\\Documents\\causal_analysis_econometrics\\"
f <- "gasoline_market.csv"
d <- read.table(paste(root,f,sep=""), header=TRUE, sep=",")

head(d)

plot(d$YEAR, d$GASEXP)
plot(d$YEAR, d$GASP)
plot(d$YEAR, d$INCOME)
plot(d$YEAR, d$POP)

d$gexp_norm <- scale(d$GASEXP, center=FALSE)
d$gp_norm <- scale(d$GASP, center=FALSE)
d$pop_norm <- scale(d$POP, center=FALSE)

model1 <- quap(
  alist(
    gexp_norm<-dnorm(mu, sigma),
    mu~ aGP + bGP*gp_norm,
    bGP~dnorm(0.3, 0.3),
    aGP~dnorm(0.1, 0.3),
    sigma~dexp(1)
  ), data=d
)

precis(model)

plot(d$GASP, d$GASEXP)

gasp_seq <- seq(from=0, to=3, length.out=30)
mu <- link(model, data=list(gp_norm=gasp_seq))
mu.mean <- apply(mu, 2, mean)
mu.PI <- apply(mu, 2, PI)
plot(gexp_norm~gp_norm, data=d, col=rangi2)
lines(gasp_seq, mu.mean, lwd=2)
shade(mu.PI, gasp_seq)

#Adding some variables now, I'll start investigating the causality
# Myhypothesis is that the following digraph is a subgraph of
# all the data

library(dagitty)
GasDag <- dagitty("dag {
    Pop->GasP
    GasP->GasExp
    Pop->GasExp
}")

coordinates(GasDag) <- list(
                            x=c(Pop=0, GasP=1, GasExp=2), 
                            y=c(Pop=0, GasP=1, GasExp=0)
                       )

drawdag(GasDag)

DMA_dag2 <- dagitty('dag{ D <- A -> M}')
impliedConditionalIndependencies(DMA_dag2)

DMA_dag1 <- dagitty('dag{D<-A -> M->D}')
impliedConditionalIndependencies(DMA_dag1)


## Under this DAG, there maybe spurious correlation if we take Pop~GasExp
## and don't also condition on GasP

## On the other hand if the arrow GasP->GasExp 
## is reversed to GasP<-GasExp, then GasP becomes 
## a collider and  conditioning on GasP causes a spurious correlation.
## Can we tell the two phenomena apart. I'll try to test this by modeling

model2 <- quap(
  alist(
    gexp_norm<-dnorm(mu, sigma),
    mu~ aP + bP*pop_norm,
    bP~dnorm(0.3, 0.3),
    aP~dnorm(0.1, 0.3),
    sigma~dexp(1)
  ), data=d
)

model3 <- quap(
  alist(
    gexp_norm<-dnorm(mu, sigma),
    mu~ aP_GP + bP*pop_norm + bGP*gp_norm,
    bGP~dnorm(0.3, 0.1),
    bP~dnorm(0.3, 0.1),
    aP_GP~dnorm(0.1, 0.1),
    sigma~dexp(1)
  ), data=d
)

precis(model2)
precis(model3)

plot(precis(model3))

## the model actually supports the hypothesis that the original
## DAG holds because the model is confident in the coefficients.
## Now let's use some information theory to test the 3 models

compare(model1, model2)
compare(model1, model3)

## these comparisons suggest that model1 is simply the best 
## and that there isn't much value adding population to this part 
## of the graph. Thus perhaps population may be an effect
## rather than a cause of GasExp

## Now I'll consider another hypothesis that population and 
## its effect on demand is logarithmic. 

model4 <- quap(
  alist(
    gexp_norm<-dnorm(mu, sigma),
    mu~ aLP_GP + bLP*log(pop_norm) + bGP*gp_norm,
    bGP~dnorm(0.3, 0.1),
    bLP~dnorm(0.3, 0.1),
    aLP_GP~dnorm(0.1, 0.1),
    sigma~dexp(1)
  ), data=d
)

plot(precis(model4))
compare(model3, model4)
compare(model1, model4)

## the code above suggests that log(population) improves the model
## but I wonder if there might be multicollinearity since the
## coefficients of correlation are pretty large.

model4a <- quap(
  alist(
    gexp_norm<-dnorm(mu, sigma),
    mu~ aLP + bLP*log(pop_norm),
    bLP~dnorm(0.3, 0.1),
    aLP~dnorm(0.1, 0.1),
    sigma~dexp(1)
  ), data=d
)

precis(model4a)
compare(model4a, model4)

plot(log(d$pop_norm), d$gexp_norm)

pairs(~pop_norm+gexp_norm+gp_norm, d)

plot(coeftab(model1, model4a, model4), pars=c("bLP", "bGP"))

## I conclude from comparing the coefficients that the log(population) and
## gas price include much of the same information and the autocorellation
## shifts size from one to the other. Hoever, the shift is not so extreme
## as to confound interpretation. The uncertainty around the coefficients
## remains mainageable. Moreover the information theoretic measures
## conclude that having both variables is still beneficial.

## Now, let's add a few more variables. I'll add them in layers
## and look at the information-theoretic criterion

d$ppt_norm<-scale(d$PPT, center=FALSE)
d$puc_norm<-scale(d$PUC, center=FALSE)
d$pnc_norm<-scale(d$PNC, center=FALSE)

model5<-quap(
  alist(
    gexp_norm<-dnorm(muGexp, sigmaGexp),
    muGexp~ aLP_GP + bLP*log(pop_norm) + bGP*gp_norm,
    bGP~dnorm(0.3, 0.1),
    bLP~dnorm(0.3, 0.1),
    aLP_GP~dnorm(0.1, 0.1),
    sigmaGexp~dexp(1),
    
    pnc_norm<-dnorm(muPnc, sigmaPnc),
    log(muPnc) ~ aLGexp+ bLGexp*gexp_norm,
    bLGexp~dnorm(0.3,0.1),
    aLGexp~dnorm(0.2,0.1),
    sigmaPnc~dexp(1)
    
  ), data=d
)


## The following plot makes me think that there is a saturation effect 
## of gas expendictures on the price of new cars
## as the amount of gas spent keeps going up, eventually
## people are unwilling to spend more on new cars

plot(~GASEXP+PNC, d)

## When I use compare, I'm not sure what the measures say. 
## however, the information criterion has gone up a lot.
## this is somewhat expected because the previous models were
## nice and clean, almost entirely linear while these have nonlinearities

compare(model4, model5)

##Now, let's add in the used car terms 

model6<-quap(
  alist(
    gexp_norm<-dnorm(muGexp, sigmaGexp),
    muGexp~ aLP_GP + bLP*log(pop_norm) + bGP*gp_norm,
    bGP~dnorm(0.3, 0.1),
    bLP~dnorm(0.3, 0.1),
    aLP_GP~dnorm(0.1, 0.1),
    sigmaGexp~dexp(1),
    
    pnc_norm<-dnorm(muPnc, sigmaPnc),
    log(muPnc) ~ aLGexpPnc + bLGexpPnc*gexp_norm,
    bLGexpPnc~dnorm(0.3,0.1),
    aLGexpPnc~dnorm(0.2,0.1),
    sigmaPnc~dexp(1),
    
    puc_norm<-dnorm(muPuc, sigmaPuc),
    log(muPuc) ~ aLGexpPuc + bLGexpPuc*gexp_norm + bPnc*pnc_norm,
    bPnc~dnorm(0.3,0.1),
    bLGexpPuc~dnorm(0.3,0.1),
    aLGexpPuc~dnorm(0.2,0.1),
    sigmaPuc~dexp(1)
    
    
  ), data=d
)

## The information-theoretic measures go down. I wonder why?
compare(model5, model6)



## I'll add interaction term between new cars and used cars as well as new cars and public transportation
## This is to explore the impact of interaction terms

## Note: the book covers different ways of expressing log normal distributions
## I will explore how to manipulate these if there's time.

model7<-quap(
  alist(
    gexp_norm<-dnorm(muGexp, sigmaGexp),
    muGexp~ aLP_GP + bLP*log(pop_norm) + bGP*gp_norm,
    bGP~dnorm(0.3, 0.1),
    bLP~dnorm(0.3, 0.1),
    aLP_GP~dnorm(0.1, 0.1),
    sigmaGexp~dexp(1),
    
    pnc_norm<-dnorm(muPnc, sigmaPnc),
    log(muPnc) ~ aLGexpPnc + bLGexpPnc*gexp_norm,
    bLGexpPnc~dnorm(0.3,0.1),
    aLGexpPnc~dnorm(0.2,0.1),
    sigmaPnc~dexp(1),
    
    puc_norm<-dnorm(muPuc, sigmaPuc),
    log(muPuc) ~ aLGexpPuc + bLGexpPuc*gexp_norm + bPnc*pnc_norm,
    bPnc~dnorm(0.3,0.1),
    bLGexpPuc~dnorm(0.3,0.1),
    aLGexpPuc~dnorm(0.2,0.1),
    sigmaPuc~dexp(1),
    
    ppt_norm<-dnorm(muPpt, sigmaPpt),
    muPpt ~ aPpt + gPucPnc*puc_norm*pnc_norm + bPptGExp*gexp_norm + bPptPuc*puc_norm ,
    gPucPnc ~ dnorm(0.2, 0.1),
    bPptGExp ~ dnorm(0.2, 0.1),
    bPptPuc ~ dnorm(0, 0.01),
    # bPptPnc ~ dnorm(0.3, 0.1),
    aPpt ~ dnorm(0.2, 0.1),
    sigmaPpt ~ dexp(1)
    
    
  ), data=d
)


model7a<-quap(
  alist(
    gexp_norm<-dnorm(muGexp, sigmaGexp),
    muGexp~ aLP_GP + bLP*log(pop_norm) + bGP*gp_norm,
    bGP~dnorm(0.3, 0.1),
    bLP~dnorm(0.3, 0.1),
    aLP_GP~dnorm(0.1, 0.1),
    sigmaGexp~dexp(1),
    
    pnc_norm<-dnorm(muPnc, sigmaPnc),
    log(muPnc) ~ aLGexpPnc + bLGexpPnc*gexp_norm,
    bLGexpPnc~dnorm(0.3,0.1),
    aLGexpPnc~dnorm(0.2,0.1),
    sigmaPnc~dexp(1),
    
    puc_norm<-dnorm(muPuc, sigmaPuc),
    log(muPuc) ~ aLGexpPuc + bLGexpPuc*gexp_norm + bPnc*pnc_norm,
    bPnc~dnorm(0.3,0.1),
    bLGexpPuc~dnorm(0.3,0.1),
    aLGexpPuc~dnorm(0.2,0.1),
    sigmaPuc~dexp(1),
    
    ppt_norm<-dnorm(muPpt, sigmaPpt),
    muPpt ~ aPpt + bPptGExp*gexp_norm + bPptPuc*puc_norm + bPptPnc *pnc_norm,
    #gPucPnc ~ dnorm(0.2, 0.1),
    bPptGExp ~ dnorm(0.2, 0.1),
    bPptPuc ~ dnorm(0.2, 0.1),
    bPptPnc ~ dnorm(0.3, 0.1),
    aPpt ~ dnorm(0.2, 0.1),
    sigmaPpt ~ dexp(1)
    
    
  ), data=d
)

## Information theoretic comparisons do not conclusively state which is better
## model7a is slightly better

compare(model7, model7a)

## Looking more closely at model7a, I tend to favor it because it is easier 
## to interpret and  the complexity of the interaction term 
## doesn't seem to improve the model noticeably
## It is notable that as one would expect, the price of used cars
## seems to impact the price of public transportation more than the 
## price of new cars. Afterall, you would expect people that buy
## used cars to be more sensitive to price, and at higher prices
## to use public-transport more. With increase demand for public transport
## along with higher gas prices, the price of public transport needs to 
## be raised to accomodate the additional costs.
## We can test this hypothesis with an interaction term

model8<-quap(
  alist(
    gexp_norm<-dnorm(muGexp, sigmaGexp),
    muGexp~ aLP_GP + bLP*log(pop_norm) + bGP*gp_norm,
    bGP~dnorm(0.3, 0.1),
    bLP~dnorm(0.3, 0.1),
    aLP_GP~dnorm(0.1, 0.1),
    sigmaGexp~dexp(1),
    
    pnc_norm<-dnorm(muPnc, sigmaPnc),
    log(muPnc) ~ aLGexpPnc + bLGexpPnc*gexp_norm,
    bLGexpPnc~dnorm(0.3,0.1),
    aLGexpPnc~dnorm(0.2,0.1),
    sigmaPnc~dexp(1),
    
    puc_norm<-dnorm(muPuc, sigmaPuc),
    log(muPuc) ~ aLGexpPuc + bLGexpPuc*gexp_norm + bPnc*pnc_norm,
    bPnc~dnorm(0.3,0.1),
    bLGexpPuc~dnorm(0.3,0.1),
    aLGexpPuc~dnorm(0.2,0.1),
    sigmaPuc~dexp(1),
    
    ppt_norm<-dnorm(muPpt, sigmaPpt),
    muPpt ~ aPpt + gPucGExp*gexp_norm*puc_norm + bPptGExp*gexp_norm + bPptPuc*puc_norm + bPptPnc *pnc_norm,
    gPucGExp ~ dnorm(0.2, 0.1),
    bPptGExp ~ dnorm(0.1, 0.05),
    bPptPuc ~ dnorm(0.2, 0.1),
    bPptPnc ~ dnorm(0.3, 0.1),
    aPpt ~ dnorm(0.2, 0.1),
    sigmaPpt ~ dexp(1)
    
    
  ), data=d
)

## Aside from just creating a hypothesis, when are interactions important and 
## how does one know to create them. The model above suggests there
## is no strong reason to suspect there is an interaction. 
## Afterall, when one is added, the coefficient essentially 
## takes on all the values allocated to a non-interaction coefficient
## Moreover, the information-theoretic measure goes up.

## I'll also add interaction terms between new cars and services
## consumer durables and nondurables will be downstream of new cars and used cars
## Hypothesis the relationship of used cars to gas price wil be nontrivial
## this might be because people may switch cars in relationship to 
## gas prices (i.e. to buy more gas-efficient cars)

d$pd_norm<-scale(d$PD)
d$pn_norm<-scale(d$PN)
d$ps_norm<-scale(d$PS)

## Some hypotheses
## 1. consumer durables will be more impacted by new cars and total gas expenditure
## 2. consumer consumables will be more impacted by used cars and he price of gasoline 
## 3. consumer services will be more impacted by consumer durables than nondurables

model9<-quap(
  alist(
    
    gexp_norm<-dnorm(muGexp, sigmaGexp),
    muGexp~ aLP_GP + bLP*log(pop_norm) + bGP*gp_norm,
    bGP~dnorm(0.3, 0.1),
    bLP~dnorm(0.3, 0.1),
    aLP_GP~dnorm(0.1, 0.1),
    sigmaGexp~dexp(1),
    
    pnc_norm<-dnorm(muPnc, sigmaPnc),
    log(muPnc) ~ aLGexpPnc + bLGexpPnc*gexp_norm,
    bLGexpPnc~dnorm(0.3,0.1),
    aLGexpPnc~dnorm(0.2,0.1),
    sigmaPnc~dexp(1),
    
    puc_norm<-dnorm(muPuc, sigmaPuc),
    log(muPuc) ~ aLGexpPuc + bLGexpPuc*gexp_norm + bPnc*pnc_norm,
    bPnc~dnorm(0.3,0.1),
    bLGexpPuc~dnorm(0.3,0.1),
    aLGexpPuc~dnorm(0.2,0.1),
    sigmaPuc~dexp(1),
    
    ppt_norm<-dnorm(muPpt, sigmaPpt),
    muPpt ~ aPpt +  bPptGExp*gexp_norm + bPptPuc*puc_norm + bPptPnc *pnc_norm,
    bPptGExp ~ dnorm(0.1, 0.05),
    bPptPuc ~ dnorm(0.2, 0.1),
    bPptPnc ~ dnorm(0.3, 0.1),
    aPpt ~ dnorm(0.2, 0.1),
    sigmaPpt ~ dexp(1),
    
    pd_norm<-dnorm(muPd, sigmaPd),
    muPd~aPd + bPdGexp*gexp_norm + bPdPnc*pnc_norm,
    bPdGexp ~dnorm(0.1, 0.05),
    bPdPnc ~ dnorm(0.1, 0.1),
    aPd ~ dnorm(0.2, 0.1),
    sigmaPd~dexp(1),
    
    pn_norm<- dnorm(muPn, sigmaPn),
    muPn~aPn + bPnGp*gp_norm + bPnPuc*puc_norm,
    bPnGp~dnorm(0.2, 0.1),
    aPn~dnorm(0.2, 0.1),
    bPnPuc~dnorm(0.2, 0.1),
    sigmaPn~dexp(1),
    
    ps_norm<- dnorm(muPs, sigmaPs),
    muPs~aPs + bPsGp*gp_norm + bPsPuc*puc_norm + bPsPn*pn_norm + bPsPpt*pt_norm,
    bPsPpt~dnorm(0.2,0.1),
    bPsGp~dnorm(0.2, 0.1),
    bPsPn~dnorm(0.2, 0.1),
    aPs~dnorm(0.2, 0.1),
    bPsPuc~dnorm(0.2, 0.1),
    sigmaPs~dexp(1)
    
    
  ), data=d
)


## just predicting price durables
model10<-quap(
  alist(
    
    gexp_norm<-dnorm(muGexp, sigmaGexp),
    muGexp~ aLP_GP + bLP*log(pop_norm),
    bLP~dnorm(0.3, 0.1),
    aLP_GP~dnorm(0.1, 0.1),
    sigmaGexp~dexp(1),
    
    pnc_norm<-dnorm(muPnc, sigmaPnc),
    log(muPnc) ~ aLGexpPnc + bLGexpPnc*gexp_norm,
    bLGexpPnc~dnorm(0.3,0.1),
    aLGexpPnc~dnorm(0.2,0.1),
    sigmaPnc~dexp(1),
    
    
    pd_norm<-dnorm(muPd, sigmaPd),
    muPd~aPd + bPdGexp*gexp_norm + bPdPnc*pnc_norm,
    bPdGexp ~dnorm(0.1, 0.05),
    bPdPnc ~ dnorm(0.1, 0.1),
    aPd ~ dnorm(0.2, 0.1),
    sigmaPd~dexp(1)
    
    
  ), data=d
)

pop_seq <- seq(from=0.5, to=1.5, length.out=30)

sim_dat<- data.frame(pop_norm=pop_seq)
s<- sim(model10, data=sim_dat, vars=c("gexp_norm", "pnc_norm","pd_norm"))

plot(sim_dat$pop_norm, colMeans(s$pd_norm), ylim=c(-3,3), type="l",
     xlab="Manipulated Population normed", ylab="Counterfactual Durables Price Index Normed")
shade(apply(s$pd_norm, 2, PI), sim_dat$pop_norm)
mtext("Total counterfactual effect of Population on the price of Durables")


plot(sim_dat$pop_norm, colMeans(s$pnc_norm), ylim=c(-3,3), type="l",
     xlab="Manipulated Population normed", ylab="Counterfactual New Cars Index Normed")
shade(apply(s$pnc_norm, 2, PI), sim_dat$pop_norm)
mtext("Total counterfactual effect of Population on the price of New Cars")
