function CI=fx_interval(success,n)
z=1.96;p=success/n;center=(p+z*z/(2*n))/(1+z*z/n);half=z*sqrt(p*(1-p)/n+z*z/(4*n*n))/(1+z*z/n);CI=[center-half center+half];
end
