function C_CCcov,tobs,sigma,mu
;This function takes a list of observation times, and produces the
;covariance matrix of the continuum light curve.

nobs = n_elements(tobs)
ti = tobs # replicate(1,nobs)
tj = transpose(ti)

;By hypothesis, the covariance matrix of the continuum is given
;below. This is equation (2) from covariance.tex

C_cc = sigma^2*Exp(-(abs(ti-tj)/mu))

return,C_cc
end

function C_CLcov_m,tobs,tpsi,psi_m,sigma,mu,w
;This function takes time indices and a guess for psi, along with the
;quasar timeseries parameters, and returns the m'th element of the
;continuum-line cross-covariance.
;
;To get the correct C_CL, sum this function over m. Note that psi and
;tpsi must both be scalars here.
if n_elements(tpsi) ne 1 then stop
if n_elements(psi_m) ne 1 then stop
nobs = n_elements(tobs)
ti = tobs # replicate(1,nobs)
tj = transpose(ti)
C_CL_m = fltarr(nobs,nobs)
dt  = ti-tj - tpsi

ind1 = where(dt gt w,ct1)
ind2 = where(dt ge -w AND dt le w,ct2)
ind3 = where(dt lt -w, ct3)

if ct1 gt 0 then begin
    y = dt[ind1]
    C_CL_m[ind1] = sigma^2*mu*psi_m/w* $
      exp(-w/mu - y/mu) * (exp(2*w/mu)-1)
endif

if ct2 gt 0 then begin
    y = dt[ind2]
    C_CL_m[ind2] = - sigma^2*mu*psi_m/w* $
      exp(-w/mu - y/mu) * $
      (1+ exp(2*y/mu) - 2*exp(w/mu+y/mu))
endif

if ct3 gt 0 then begin
    y = dt[ind3]
    C_CL_m[ind3] = sigma^2*mu*psi_m/w * $
      2*exp(y/mu)*sinh(w/mu)
endif

return,C_CL_m/2.
end


function C_LLcov_mn,tobs,tpsi_m,tpsi_n,psi_m,psi_n,sigma,mu,w
if n_elements(tpsi_m) ne 1 then stop
if n_elements(psi_m) ne 1 then stop
if n_elements(tpsi_n) ne 1 then stop
if n_elements(psi_n) ne 1 then stop
nobs = n_elements(tobs)
ti = tobs # replicate(1,nobs)
tj = transpose(ti)

dt = ti-tj + (tpsi_m-tpsi_n)



C_LL_mn = fltarr(nobs,nobs)

ind1 = where(dt gt  w,ct1)
ind2 = where(dt lt -w,ct2)
ind3 = where(dt ge -w AND dt le 0, ct3)
ind4 = where(dt gt  0 AND dt le w, ct4)

if ct1 gt 0 then begin
    y = dt[ind1]
    C_LL_mn[ind1] = sigma^2*mu^2/w^2*psi_m*psi_n * $
      exp(-w/mu - y/mu)*(exp(w/mu)-1.)^2
endif

if ct2 gt 0 then begin
    y = dt[ind2]
    C_LL_mn[ind2] = sigma^2*mu^2/w^2*psi_m*psi_n * $
      exp(-w/mu + y/mu)*(exp(w/mu)-1.)^2
endif
if ct3 gt 0 then begin
    y = dt[ind3]
    C_LL_mn[ind3] = -sigma^2*mu/w^2*psi_m*psi_n * $
      exp(-w/mu-y/mu) * $
      (-mu - mu*exp(2*y/mu) + 2*mu*exp(w/mu+2*y/mu) - 2*w*exp(w/mu+y/mu) $
       - 2*y*exp(w/mu+y/mu))
endif
if ct4 gt 0 then begin
    y = dt[ind4]
    C_LL_mn[ind4] = sigma^2*mu/w^2*psi_m*psi_n * $
      exp(-w/mu-y/mu) * $
      (mu - 2*mu*exp(w/mu) + mu*exp(2*y/mu) + 2*w*exp(w/mu+y/mu) - $
       2*y*exp(w/mu+y/mu))
endif

return,C_LL_mn
end

pro reverb_covariance,tobs,tpsi,psi_in,w,sigma=sigma,mu=mu,$
                      covar=C,C_CC=C_CC,C_CL=C_CL,C_LL=C_LL,$
                      noise=noise

nobs = n_elements(tobs)
npsi = n_elements(tpsi)

if ~keyword_set(psi_in) then psi_in = replicate(1./float(npsi),npsi)
if ~keyword_set(sigma) then sigma = 1.0
if ~keyword_set(mu) then mu = 100.

C_CL  = fltarr(nobs,nobs)
C_CLt = fltarr(nobs,nobs)
C_LL  = fltarr(nobs,nobs)


C_CC = C_CCcov(tobs,sigma,mu)
;print,'making C_CL:'
for m = 0L,npsi-1 do begin
;    print,string(form= '("Progress:",I02,"%")',float(m)/float(npsi)*100.)
    C_CL  += C_CLcov_m( tobs,tpsi[m],psi_in[m],sigma,mu,w)
    C_CLt += C_CLcov_m(-tobs,tpsi[m],psi_in[m],sigma,mu,w)
endfor
;print,'Making C_LL:'
for m = 0L,npsi-1 do begin
;    print,string(form= '("Progress:",I02,"%")',float(m)/float(npsi)*100.)
    for n=0L,npsi-1 do begin
        C_LL += C_LLcov_mn(tobs,tpsi[m],tpsi[n],psi_in[m],psi_in[n],sigma,mu,w)
    endfor
endfor

Ncovar = diag_matrix(noise)

;Make the Big Covariance Matrix.

C = [[C_CC,C_CL],[C_CLt,C_LL]]+Ncovar
end
