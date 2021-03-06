% Simulate scene and calculate F from simulated correspondences
% in:
%     1. Fparam.f1/Fparam.f2 - focal length.
%        Fparam.per_corr - number of F-s returned, each differing only in
%       noise. Don't use it, it's ignored. 
%     2. noise - determines std of additive noise in pixels, which is added to
%       correspondences
%     3. method - for calculating F, see uu2F
% out:
%     1. F - fundamental matrix.
%     2. A - scaling matrices.
%     2. u - correspondences.
%
% Oleh Rybkin, rybkiole@fel.cvut.cz
% INRIA, 2016

function [F,A,u,P] = F_simulate( Fparam, method )
old_version=false;
%% Initialize
global ps;
ps.plot    = true;
if ~old_version
    %% using scene generator from Zuzana.
    % beware, hacky rescaling. 
    sceneType = {'randombox' 'random'};
    pixel = 1/1000; %rescaling to pixels. in the output of GenerateScene the image will be always between -1 and 1, they say, so 2000 pixels
    noise = Fparam.noise*pixel;
    f1=Fparam.f1*pixel;
    f2=Fparam.f2*pixel;
    fmax=max(f1,f2);
    Npoints = Fparam.corr;
    Ncams = 2;
    Kgt1 = diag([f1 f1 1]);
    Kgt2 = diag([f2 f2 1]);
    gtk1 = 0;
    gtk2 = 0;
    [P, ~, m, ~] = GenerateScene(Npoints, [10*fmax 10*fmax], Ncams, 20*fmax, 30*fmax, 0, noise, [Kgt1;Kgt2], sceneType, [], [], [gtk1,gtk2], true);
    sample=randperm(size(m{1},2),Fparam.corr);
    u={m{1}(:,sample)/pixel m{2}(:,sample)/pixel}; %rescaling back
    testsample=setdiff(1:Npoints,sample); %mini RANSAC is running inside F_features
    testset={m{1}(:,testsample)/pixel m{2}(:,testsample)/pixel};
    [F{1},A{1}]=F_features(u{1}, u{2},method,testset);
    u={u{1}*A{1}{1}(1) u{2}*A{1}{2}(1)}; %rescaling forth. u is now in the same scale as F, but f isn't.
else
   %% OLD VERSION, MAY NOT WORK
    %tic();
    % focal lengths
    sc = max(Fparam.f1,Fparam.f2);
    % Internal camera calibration
    K1 = [Fparam.f1  0    0
        0   Fparam.f1   0
        0   0    1];
    K2 = [Fparam.f2 0  0
        0  Fparam.f2 0
        0  0  1];
    % Setup
    % Two cameras are looking in the direction of set of points with deviation
    % at most _angles_, angle between cameras is at most _anled_, distances
    % to the center of point set are ~ _dists_.
    angles=pi/8*rand();
    angled=pi/4*rand();
    dists=5*sc+sc*rand(2,1)
    % Rotations
    R1 = eye(3);
    R2 = a2r(rand(3,1),pi/8);
    % Projection matrices
    P1 = K1*R1*[eye(3)                      [0; 0; dists(1)]];
    P2 = K2*R2*[eye(3)  a2r([0; 0; 1],pi/3)*[0; 0; dists(2)]];
    
    if noise
        [F,A]=simulate_corr(P1,P2,sc,Fparam.noise,Fparam, method);
    else
        F{1} = PP2F(P1,P2); % from projection matrices, ground truth
        A={eye(3) eye(3)};
        F{1}=reshape(F{1},9,1);
        F{1} = F{1}/norm(F{1});  [~,mi] = max(abs(F{1})); F{1} = F{1}*sign(F{1}(mi));
    end
end
end


function [F,A]=simulate_corr(P1,P2,sc,noise,Fparam, method)
%calculate F matrix from random correspondences
%part of old version

global ps;
% 3D points
X = 2*sc*randn(3,Fparam.corr);
% Image points
u1 = X2u(X,P1);
u2 = X2u(X,P2);
F=cell(Fparam.per_corr,1);
A=cell(Fparam.per_corr,1);
for i=1:Fparam.per_corr
    % add image noise
    u1(1:2,:)=u1(1:2,:)+noise*randn(size(u1(1:2,:)));
    u2(1:2,:)=u2(1:2,:)+noise*randn(size(u2(1:2,:)));
    [F{i},A{i}]=F_features(u1,u2, method);
end
if ps.plot
    % Plot cameras & 3D points
    subfig(3,4,1);
    camplot(P1,[],Fparam.f1/2*[-1 1 1 -1;-1 -1 1 1]);hold; camplot(P2,[],Fparam.f2/2*[-1 1 1 -1;-1 -1 1 1]);
    plot3d(X,'.');
    axis equal
    title('Cameras & 3D points (''.b'')')
    % Plot images
    subfig(3,4,2);plot3d(u1(1:2,:),'.');axis image;title('Image 1');
    subfig(3,4,3);plot3d(u2(1:2,:),'.');axis image;title('Image 2');
end
end


