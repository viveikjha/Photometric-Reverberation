
;; NPR: I'm presuming this is Eqn (2) for the current draft of
;; covariance.pdf. If so, it looks as if it represents that equation
;; OKAY TO ME
function C_CCcov,tobs,sigma,mu
  nobs = n_elements(tobs)
  ti = tobs # replicate(1,nobs)
  tj = transpose(ti)
  
C_cc = sigma^2*Exp(-(abs(ti-tj)/mu))

return,C_cc
end

function C_CLcov_m,tobs,tpsi,psi_m,sigma,mu,w,delta_t
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
ind1 = where(abs(ti - tj - tpsi) gt w/2.,ct1)
ind2 = where(abs(ti - tj - tpsi) le w/2.,ct2)
if ct1 gt 0 then C_CL_m[ind1] = 2*mu*psi_m*sigma^2*$
  exp(-abs(dt[ind1])/mu)*sinh(w/2/mu)/delta_t
if ct2 gt 0 then C_CL_m[ind2] = 2*mu*psi_m*sigma^2*$
  (1.-exp(-w/2/mu)*cosh((dt[ind2])/mu))/delta_t
return,C_CL_m
end

;;
;; NPR: I'm presuming this is Eqn (26) for the current draft of
;; covariance.pdf. If so, these are beginning to look okay to me, 
;; but for both options, gt w and le w, the if clauses are looking
;; pretty similar. 
;; I'm assuming with abs(dt) le w, then the [1+mu*(exp^(-mu/w)-1] 
;; tends to mu/w in order to give you the mu^2 term?
;;
function C_LLcov_mn,tobs,tpsi_m,tpsi_n,psi_m,psi_n,sigma,mu,w,delta_t
if n_elements(tpsi_m) ne 1 then stop
if n_elements(psi_m) ne 1 then stop
if n_elements(tpsi_n) ne 1 then stop
if n_elements(psi_n) ne 1 then stop
nobs = n_elements(tobs)
ti = tobs # replicate(1,nobs)
tj = transpose(ti)

dt = ti-tj + (tpsi_m-tpsi_n)

C_LL_mn = fltarr(nobs,nobs)

ind1 = where(abs( dt ) gt w,ct1)
ind2 = where(abs( dt ) le w,ct2)

;if ct1 gt 0 then $
;  C_LL_mn[ind1] = psi_m*psi_n*sigma^2*exp(-abs(dt[ind1])/mu)*2*(mu/w)^2*$
;  (cosh(w/mu)-1)
;if ct2 gt 0 then $
;  C_LL_mn[ind2] = psi_m*psi_n*sigma^2*2*mu/w*cosh(dt[ind2]/mu)*$
;  (1+mu/w*(exp(-mu/w)-1))
if ct1 gt 0 then $
  C_LL_mn[ind1] = mu^2 * sigma^2 * psi_m * psi_n*$
  (exp(-abs(dt[ind1]-w)/mu) + exp(-abs(dt[ind1]+w)/mu)-2*exp(-abs(dt[ind1])))
if ct2 gt 0 then $
  C_LL_mn[ind2] = mu^2 * sigma^2 * psi_m * psi_n*$
  (exp(-abs(dt[ind2]-w)/mu) + exp(-abs(dt[ind2]+w)/mu)-2*exp(-abs(dt[ind2]))); $
;   - 2*abs(abs(dt[ind2])-w)/mu)
;if total(C_LL_mn lt 0) gt 0 then stop
return,C_LL_mn
end

pro optimal_estimator,tobs,tpsi,data,w,dt,sigma=sigma,mu=mu,$
                      psi_in=psi_in,psi_out=psi_out,$
                      C_CC=C_CC,C_CL=C_CL,C_LL=C_LL,$
                      noise=noise

nobs = n_elements(tobs)
npsi = n_elements(tpsi)

if ~keyword_set(psi_in) then psi_in = replicate(1./float(npsi),npsi)
if ~keyword_set(sigma) then sigma = 1.0
if ~keyword_set(mu) then mu = 100.

C_CL = fltarr(nobs,nobs)
C_LL = fltarr(nobs,nobs)


C_CC = C_CCcov(tobs,sigma,mu)
print,'making C_CL:'
for m = 0L,npsi-1 do begin
    print,string(form= '("Progress:",I02,"%")',float(m)/float(npsi)*100.)
    C_CL += C_CLcov_m(tobs,tpsi[m],psi_in[m],sigma,mu,w,dt)
endfor
print,'Making C_LL:'
for m = 0L,npsi-1 do begin
    print,string(form= '("Progress:",I02,"%")',float(m)/float(npsi)*100.)
    for n=0L,npsi-1 do begin
        C_LL += C_LLcov_mn(tobs,tpsi[m],tpsi[n],psi_in[m],psi_in[n],sigma,mu,w,dt)
    endfor
endfor

Ncovar = diag_matrix(noise)

;Make the Big Covariance Matrix.

C = [[C_CC,C_CL],[C_CL,C_LL]]+Ncovar
Cinv = LA_invert(C,status=status)
Fisher = dblarr(npsi,npsi)
q = dblarr(npsi)
f = dblarr(npsi)
;Make the Fisher matrix.
print,'Building the Fisher Matrix.'
for n = 0,npsi-1 do begin
    print,string(form= '("Progress:",I02,"%")',float(n)/float(npsi)*100.)
    for m = 0,npsi-1 do begin
        dCL_dpsi_m = C_CLcov_m(tobs,tpsi[m],1.,sigma,mu,w,dt)
        dCL_dpsi_n = C_CLcov_m(tobs,tpsi[n],1.,sigma,mu,w,dt)
        dLL_dpsi_m = fltarr(nobs,nobs)
        dLL_dpsi_n = fltarr(nobs,nobs)
        for i = 0,npsi-1 do begin
            dLL_dpsi_m += C_LLcov_mn(tobs,tpsi[m],tpsi[i],1.,psi_in[i],sigma,mu,w,dt)
            dLL_dpsi_n += C_LLcov_mn(tobs,tpsi[i],1.,psi_in[i],psi_in[n],sigma,mu,w,dt)
        endfor
;Now make dC_dm:
        dC_dm = [[C_CC*0.,dCL_dpsi_m],[dCL_dpsi_m,dLL_dpsi_m]]
;And make dC_dn:
        dC_dn = [[C_CC*0.,dCL_dpsi_n],[dCL_dpsi_n,dLL_dpsi_n]]
        Fisher[m,n] = 0.5*trace(Cinv # dC_dm # Cinv # dC_dn)
    endfor
    q[n] = 0.5*trace(Cinv # dC_dn # Cinv # Ncovar)
    f[n] = 0.5*transpose(data)# Cinv # dC_dn # Cinv # data
endfor

Finv = LA_invert(Fisher,status=status2)
psi_out = Finv # (q-f)

end
