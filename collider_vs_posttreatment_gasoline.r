root <- "C:\\Users\\tenni\\Documents\\causal_analysis_econometrics\\"
f <- "gasoline_market.csv"
d <- read.table(paste(root,f,sep=""), header=TRUE, sep=",")

d$gexp_norm <- scale(d$GASEXP, center=FALSE)
d$gp_norm <- scale(d$GASP, center=FALSE)
d$pop_norm <- scale(d$POP, center=FALSE)

## Now trying to predict GasP instead, I notice GasP is a collider 
## under this model, so let's see if it behaves like one
## so if I condition on it, then it's supposed to introduce bias

model5a <- quap(
  alist(
    gp_norm<-dnorm(mu, sigma),
    mu~ a + b*log(pop_norm) + c*gexp_norm,
    c~dnorm(0.1,0.1),
    b~dnorm(0.3, 0.1),
    a~dnorm(0.1, 0.1),
    sigma~dexp(1)
  ), data=d
)

precis(model5a)

model5b <- quap(
  alist(
    gp_norm<-dnorm(mu, sigma),
    mu~ a + b*log(pop_norm),
    b~dnorm(0.3, 0.1),
    a~dnorm(0.1, 0.1),
    sigma~dexp(1)
  ), data=d
)

precis(model5b)

compare(model5a, model5b)

## The information theoretic measures suggest that model 5a is far superior 
## to model 5b. This opposes my intuition that 
## including GasExp introduces a collider and makes the model biased
## of course, indicating if there is collider bias is not
## what the information-theoretic measures are supposed to do.
## My conclusion from this series of manipulations is that
## these manipulations do not help us reason whether 
## the causal graph is correct.

## What other variables might we model population as
## now that I think about it population and an intermediary 
## variable demand might be like a poisson distribution