clc
%%
clear all
%%
% (a)
%%
%读取数据
return_m_hor = readtable('return_monthly.xlsx','ReadVariableNames',true,'PreserveVariableNames',true,'Format','auto');
me_lag = readtable('me_lag.xlsx','ReadVariableNames',true,'PreserveVariableNames',true,'Format','auto');
%%
%转化为long数据
long_return_m = stack(return_m_hor,3:127,"NewDataVariableName",'return','IndexVariableName','date');
long_me_lag = stack(me_lag,3:127,"NewDataVariableName",'me_lag','IndexVariableName','date');
%%
%两个表连接一下成为mydata
mydata = innerjoin(long_return_m,long_me_lag,"Keys",{'code','date','name'});
%%
%去除mydata中的缺失值成为mydata1
mydata1 = mydata(~isnan(mydata.return)&~isnan(mydata.me_lag)&(mydata.me_lag>0),:);
%上面就已经完成了（1），融合后的表是mydata1
%%
% (2)
%%
%下面对mydata1按照时间分组，获得yymm列
[G,date] = findgroups(mydata1.date);% 按照时间进行分组
mydata1_eachday_equal_weighted_return = splitapply(@(x)mean(x),mydata1.return,G);

return_eachday = table(date,mydata1_eachday_equal_weighted_return);

mydata1.date = char(mydata1.date);
mydata1.year = year(mydata1.date);
mydata1.month = month(mydata1.date);
mydata1.yymm = mydata1.year*12+mydata1.month;
%%
%截取mydata1中有用的列，成为mydata4
mydata4 = table(mydata1.code,mydata1.name,mydata1.date,mydata1.return,mydata1.yymm,mydata1.me_lag,'VariableNames',{'code','name','date','return','yymm','me_lag'});
%%
%将return统一平移（考虑到了公司之间的接合处），并求一下前K月的收益，与包括这个月和之后K-1个月的收益
for K = [1, 3, 6, 12, 24]
    mydata1_try = mydata1;
    mydata2 = mydata1;
    mydata2.yymm = mydata1.yymm+K;
    newReturnName = strcat('return_lag', num2str(K));
    mydata2 = renamevars(mydata2, 'return', newReturnName);
    mydata3 = outerjoin(mydata1_try, mydata2, 'Keys', {'code','yymm'},'MergeKeys',true,'Type','left');
    mydata4.(newReturnName) = mydata3.(newReturnName);
end

for K = [1, 3, 6, 12, 24]
    newReturnName = strcat('return_lag', num2str(K));
    newReturnName_mean = strcat('return_lag_mean', num2str(K));
    % 计算滑动平均并将结果赋值给新列
    mydata4.(newReturnName_mean) = movmean(mydata4.(newReturnName), [0 K-1]);
    mydata4 = removevars(mydata4, newReturnName);
    newReturnName_lead = strcat('return_lead_mean', num2str(K));
    mydata4.(newReturnName_lead) = movmean(mydata4.return, [0 K-1]);
end
%这里就获得了新的mydata4，包含基础信息，以及K不同取值下，lag和lead的收益平均值

%%
%下面按照lag的收益做分组，计算lead的收益
group_return_diffK = zeros(5,5);
K_list = [1, 3, 6, 12, 24];
for K_index = 1:5
    K = K_list(K_index);
    selectedColumns = [1:6, 6 + 2*K_index-1, 6 + 2*K_index];
    mydata_K_try = mydata4(:, selectedColumns);
    newReturnName_mean = strcat('return_lag_mean', num2str(K));
    mydata_K_try = mydata_K_try(~isnan(mydata_K_try.(newReturnName_mean)), :);

    [G,yymm] = findgroups(mydata_K_try.yymm);
    %这里，表示根据jdate分组，G表示每一行所属组的序号，jdate则会是每一组的代表性元素
    mydata_K_try_breaks = table(yymm);
    
    prctile_20 = @(input)prctile(input,20);
    prctile_40 = @(input)prctile(input,40);
    prctile_60 = @(input)prctile(input,60);
    prctile_80 = @(input)prctile(input,80);
    
    mydata_K_try_breaks.rt20 = splitapply(prctile_20,mydata_K_try.(newReturnName_mean),G);
    mydata_K_try_breaks.rt40 = splitapply(prctile_40,mydata_K_try.(newReturnName_mean),G);
    mydata_K_try_breaks.rt60 = splitapply(prctile_60,mydata_K_try.(newReturnName_mean),G);
    mydata_K_try_breaks.rt80 = splitapply(prctile_80,mydata_K_try.(newReturnName_mean),G);
    
    mydata_K_try = outerjoin(mydata_K_try,mydata_K_try_breaks,'Keys',{'yymm'},'MergeKeys',true,'Type','left');

    rtport = rowfun(@rt_bucket,mydata_K_try(:,{newReturnName_mean,'rt20','rt40','rt60','rt80'}),'OutputVariableNames','cell');
    mydata_K_try.rtport = table2array(rtport);

    if K==3
        save return_K3.mat mydata_K_try;
    end

    [G,~] = findgroups(mydata_K_try.rtport);
    newReturnName_lead = strcat('return_lead_mean', num2str(K));
    rt_group_mean = splitapply(@mean,mydata_K_try.(newReturnName_lead),G);
    group_return_diffK(:,K_index) = rt_group_mean;
end
%这里就获得了最后的group_return_diffK，是不同K取值，不同组的平均return
%%
fprintf('K:    1      3      6      12     24\n');

for i = 1:5
    fprintf('组%d ', i);
    fprintf(' %.2f   %.2f   %.2f   %.2f   %.2f\n', group_return_diffK(i, :));
end
fprintf('\n')
%%
%计算最大组和最小组之间的spread
group_return_spread = zeros(1,5);
for i = 1:5
    group_return_spread(i) = group_return_diffK(5,i)-group_return_diffK(1,i);
end

fprintf('K:      1             3             6             12             24\n');

for i = 1:5
    fprintf('      %.2f   %.2f   %.2f   %.2f   %.2f\n', group_return_spread(i));
end
fprintf('\n')
%%
% (3)
%%
% 导入return_K3.mat文件，计算各组的平均收益
return_K3 = load('return_K3.mat');
return_K3 = return_K3.mydata_K_try;

[G,yymm,rtport] = findgroups(return_K3.yymm, return_K3.rtport);

ewret = splitapply(@mean,return_K3(:,{'return_lead_mean3'}),G);

ewret_table = table(yymm,rtport,ewret);

mom_factors = unstack(ewret_table(:,{'ewret','yymm','rtport'}),'ewret','rtport');

mom_factors = mom_factors(~isnan(mom_factors.x1)&~isnan(mom_factors.x2)&~isnan(mom_factors.x3)&~isnan(mom_factors.x4)&~isnan(mom_factors.x5),:);

low_return = mean(table2array(mom_factors(:,2)));

high_return = mean(table2array(mom_factors(:,6)));

fprintf('The average return for the low previous return group is %4.3f percent \n',low_return)
fprintf('The average return for the high previous return group is %4.3f percent \n',high_return)
fprintf('\n')

plot(mean(table2array(mom_factors(:,2:6))),'-x')
xticks(1:1:5)
xlabel('Group')
ylabel('Equal-Weighted Average Return')

%%
% PCA分析和MOM因子构建

mom_pca = table2array(mom_factors(:,2:6));

[coefMatrix, score, latent, tsquared, explainedVar] = pca(mom_pca);

factors = mom_pca*coefMatrix;
first_three_factors = factors(:,1:3);

residSD = zeros(5,1);
gamma1 = zeros(5,1);gamma2 = zeros(5,1);gamma3 = zeros(5,1);
constant = ones(length(first_three_factors),1);
for i = 1:5
    [b,bint,r,rint,stats] = regress(mom_pca(:,i),[constant,first_three_factors]);
    residSD(i) = sqrt(stats(4));
    gamma1(i) = b(2);
    gamma2(i) = b(3);
    gamma3(i) = b(4);
end

plot([gamma1,gamma2,gamma3],'-x');
xticks(1:1:5)
xlabel('Group')
ylabel('Factor Loading')
legend('First','Second','Third');

mom = mom_pca(:,5)-mom_pca(:,1);

fprintf('the corr between mom factor and the first pca factor is %4.3f \n', corr(factors(:,1), mom))
fprintf('the corr between mom factor and the second pca factor is %4.3f \n', corr(factors(:,2), mom))
fprintf('the corr between mom factor and the third pca factor is %4.3f \n', corr(factors(:,3), mom))
fprintf('the corr between mom factor and the fourth pca factor is %4.3f \n', corr(factors(:,4), mom))
fprintf('the corr between mom factor and the fifth pca factor is %4.3f \n', corr(factors(:,5), mom))

% 第一主成分只控制了level，对于解释收益差异没有帮助
% 第二主成分的factor loading在过去低收益组为正，过去高收益组为负，呈单调下降趋势
% 第二主成分的增加会使得过去低收益组在未来的收益增加，过去高收益组在未来的收益减少，解释了收益的差异

% mom因子和pca五个主成分的相关性依次为-0.227, -0.967, 0.061, 0.103, 0.000
% mom因子与第二主成分高度负相关，说明mom因子具有斜率结构，以及mom的减少会使得过去高收益组在未来的收益减少
% 因此中国股票市场动量效应不明显，反转效应更明显

