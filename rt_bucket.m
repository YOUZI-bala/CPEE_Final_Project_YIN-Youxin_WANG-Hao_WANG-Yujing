function value = rt_bucket(return_K3,rt20,rt40,rt60,rt80)
%UNTITLED2 此处显示有关此函数的摘要
%   此处显示详细说明
if isnan(return_K3)
    value=blanks(1);
elseif return_K3<=rt20
    value='1';
elseif return_K3>rt20 & return_K3<=rt40 
    value='2';
elseif return_K3>rt40 & return_K3<=rt60 
    value='3';
elseif return_K3>rt60 & return_K3<=rt80 
    value='4';
elseif return_K3>rt80
    value='5';
else
    value=blanks(1);
end