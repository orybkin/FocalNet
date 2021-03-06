% A script for generating scatter plots of Bougnoux formula results from correspondences file
%
% stat_data:=[absolute_error; a_std; relative_error; r_std]
% data:={absolute_error a_std relative_error r_std
%        absolute_error_img a_std_img relative_error_img r_std_img}
%
%
% Oleh Rybkin, rybkiole@fel.cvut.cz
% INRIA, 2016

function [stat_data, data]=bougnoux_scatter(file,corr,pop_size, method, noise,plotting)
if strcmp(method,'Free') && corr<8
    data={[] [] [] []}';
    stat_data=nan(2,4);
    return;
end
[estion,truth]=calcFocals(file,corr,pop_size, method, noise);

tic();
focalscell=num2cell(estion,2);
real_idx=cellfun(@isreal,focalscell);
img_idx=logical(1-real_idx);

%calculate statistical data
get_ratio=@(x) abs(x(:,1))./abs(x(:,2));
ratio_estion=get_ratio(estion);
ratio_truth=get_ratio(truth);

error=@(x,y) abs(abs(x(:,1))-abs(y(:,1)));
foc_error=error(estion,truth);
rat_error=error(ratio_estion, ratio_truth);
data{1}=foc_error(real_idx);
data{2}=foc_error(img_idx);
data{3}=rat_error(real_idx);
data{4}=rat_error(img_idx);
%
getmean=@(x)  mean(mean(x,1));
getstd=@(x)  mean(std(x,[],1));
stat_data(:,1)=[(getmean(data{1})) (getmean(data{2}))];
stat_data(:,2)=[getstd(data{1}) getstd(data{2})];
stat_data(:,3)=[getmean(data{3}) getmean(data{4})];
stat_data(:,4)=[getstd(data{3}) getstd(data{4})];
%toc();
%plot
if plotting
    scatter(abs(estion(real_idx,1)),abs(estion(real_idx,2)),'b+','DisplayName','real f');
    hold on
    if any(img_idx==1)
        scatter(abs(estion(img_idx,1)),abs(estion(img_idx,2)),'r+','DisplayName','imaginary f');
    end
    scatter(1500,2000,60,'filled','go','DisplayName','ground truth','LineWidth',5);
    plot([0 3000],[0 4000],'g','DisplayName','correct proportion line');
    axis([0 4000 0 4000]);
    %triffles
    [~,~]=legend('-DynamicLegend'); % don't change this line - it fixes a Matlab bug
    title({['Bougnoux formula estimation from ' int2str(corr) ' correspondences.  method = ' method], ...
        [ '[real all] : mean error = ' mat2str(stat_data(:,1),3) '; std = ' mat2str(stat_data(:,2),3)]});
    xlabel('abs(f2)');
    ylabel('abs(f1)');
    method=strrep(method,'|','');
    name=['bougnoux/scatter/bougnoux_corr=' int2str(corr) '_' method];
    saveas(gcf,[name  '.fig']);
    saveas(gcf,[name '.jpg']);
    hold off
end
%toc();
end

function [estion,truth]=calcFocals(file,corr,n,method,noise)
global debugg;
%get n focal length estimations of the bougnoux formula on corr coordinates from the data in
%specified file

%load data
load(file);
u=[corr_tr.u corr_val.u corr_tst.u];
truth=[corr_tr.f corr_val.f corr_tst.f];
norm_=[corr_tr.norm corr_val.norm corr_tst.norm];
%truncate
u=u(:,1:n); truth=truth(:,1:n)'; norm_=norm_(:,1:n)';
estion=zeros(n,2);
rng(867954152); %the reason I create noise beforehand is that now I can be sure 
%for every call of this method the noise will be the same, which allows for
%comparison
noisy=noise*randn(2,n);
noisy(:,1);


for i=1:n
    %reshape
    uvector=u(:,i);
    points=size(uvector,1)/4;
    u1=reshape(uvector(1:end/2), 2, points);
    u2=reshape(uvector(end/2+1:end), 2, points);
    %truncate
    sample=1:corr;
    %sample=randperm(size(u1,2),corr);
    testsample=setdiff(1:size(u1,2),sample);
    testset={u1(:,testsample) u2(:,testsample)};
    u1=u1(:,sample);
    u2=u2(:,sample);
    %noise
    u1(:,1)=u1(:,1)+noisy(:,i);
        
 
    crucial=5;
    %calculate
    if i==crucial 
        debugg=0;
        
        method;
    else
        debugg=0;
    end
        
    [Fund,A]=F_features(u1,u2,method,testset,3,false);
    %method
    %little_ransac(reshape(Fund,3,3),A,testset,3,false);
    estion(i,:)=F2f1f2(reshape(Fund,3,3));
    estion(i,:)=estion(i,:)*diag([1/A{1}(1) 1/A{2}(1)]).*norm_(i,:);
    truth(i,:)=truth(i,:).*norm_(i,:);
    if i==crucial
       % estion(i,:)
     %   estion(i,1)/estion(i,2)
    end
    
end
end

function a=multabs(a)
%absolute value with respect to multiplication. super important function.
if abs(a)<1
    a=1/a;
end    
end

function Fparam=getFparam(corr)
% DATED
%get a structure with camera system parameters
Fparam.corr=corr; % number of correspondences
Fparam.f1=900;
Fparam.f2=1100;
Fparam.points=rand(3,Fparam.corr);
Fparam.raxis=rand(3,1); % r
Fparam.tpos=rand(2,1);
end