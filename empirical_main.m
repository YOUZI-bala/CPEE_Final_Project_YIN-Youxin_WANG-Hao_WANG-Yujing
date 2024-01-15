clear
close all
crsp=readtable('crsp_port.csv');
beta=readtable('beta.csv');
beta=beta(:,[1,2,5]);
beta.Properties.VariableNames={'permno','date','beta'};
beta.date=datetime(beta.date,'ConvertFrom','yyyyMMdd','format','yyyy/MM/dd');
Rf=readtable('Rf_mkt.CSV');

crsp.yymm=12*year(crsp.date)+month(crsp.date);
crsplag=crsp;
crsplag.yymm=crsplag.yymm-1;
crsplag.ereturn=crsplag.retadj;
crsplag.wt=crsplag.me;
crsp=innerjoin(crsp,crsplag(:,{'ereturn','yymm','permno','wt'}),'Keys',{'yymm','permno'});
crsp.me=log(crsp.me);
%%

%% Fama-Macbeth
crsp1=innerjoin(crsp,beta,'Keys',{'permno','date'});

flexvar=[crsp1.beta,crsp1.me,crsp1.beme];

[G,jdate]=findgroups(crsp1.date);

myfun=@(x1,x2){regress(x1,x2)'};
loading=cell2mat(splitapply(myfun,crsp1.ereturn,[ones(height(crsp1),1) flexvar],G));


coef=zeros(size(loading,2),1);
t=zeros(size(loading,2),1);
for i=1:size(loading,2)
    coef(i)=mean(loading(:,i));
    t(i)=mean(loading(:,i))*sqrt(size(loading,1))/std(loading(:,i));
end
ttable=array2table(t,'RowNames',{'cons','beta','size','b-m ratio'});
disp(ttable)
