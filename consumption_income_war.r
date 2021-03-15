library(rethinking)

path <- "C:\\Users\\tenni\\Documents\\causal_analysis_econometrics\\consumption_income_war.csv"
dat <- read.table(path, header=TRUE, sep=",")

dat$wid <- ifelse(dat$W==0,1,2)
dat$income_norm = scale(dat$X, center=FALSE)
dat$consumption_norm = scale(dat$C, center=FALSE)

income_consumption_model <- quap(
  alist(
    consumption_norm~dnorm(mu, sigma),
    mu <- a[wid] + b[wid]*income_norm,
    a[wid]~dnorm(1, 0.1),
    b[wid]~dnorm(.5, 0.3),
    sigma~dexp(1)
  ), data=dat
)



## simpler plotting

precis(model, depth=2)
plot(precis(model, depth=2))


income_seq <- seq(from=min(dat$income_norm)-0.1, to=max(dat$income_norm)+0.1, length.out=30)

plot(dat$income_norm, dat$consumption_norm,)

mu <- link(model, data=data.frame(wid=1, income_norm=income_seq))
mu_mean <- apply(mu, 2, mean)
mu_ci <- apply(mu,2,PI, prob=0.97)
lines(income_seq, mu_mean, lwd=2)
shade(mu_ci, income_seq, col=col.alpha(rangi2,0.3))
mtext("Non-War")


mu <- link(model, data=data.frame(wid=2, income_norm=income_seq))
mu_mean <- apply(mu, 2, mean)
mu_ci <- apply(mu,2,PI, prob=0.97)
lines(income_seq, mu_mean, lwd=2)
shade(mu_ci, income_seq, col=col.alpha(rangi2,0.3))
mtext("War")


# View prior first
prior <- extract.prior(model)
mu <- link(model, post=prior, data=data.frame(wid=c(2,2),income_norm=c(-2,2)))

plot(NULL, xlim=c(-2,2), ylim=c(-2,2))
for( i in 1:50) lines(c(-2,2), mu[i,], col=col.alpha("black",0.4))


#view posterior

income_seq <- seq(from=-3, to=3, length.out=30)
mu <- link(model, data=data.frame(wid=1, income_norm=income_seq))
mu.mean <- apply(mu, 2, mean)
mu.PI <- apply(mu, 2, PI)
plot(consumption_norm~income_norm, data=dat, col=rangi2)
lines(income_seq, mu.mean, lwd=2)
shade(mu.PI, income_seq)

mu <- link(model, data=data.frame(wid=2, income_norm=income_seq))
mu.mean <- apply(mu, 2, mean)
mu.PI <- apply(mu, 2, PI)
lines(income_seq, mu.mean, lwd=2)
shade(mu.PI, income_seq)

