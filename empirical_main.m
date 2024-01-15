clear
close all
crsp=readtable('crsp_port.csv');

crsp.yymm=12*year(crsp.date)+month(crsp.date);
crsplag=crsp;
crsplag.yymm=crsplag.yymm-1;
crsplag.ereturn=crsplag.retadj;

crsp=innerjoin(crsp,crsplag(:,{'ereturn','yymm','permno'}),'Keys',{'yymm','permno'});
%%
