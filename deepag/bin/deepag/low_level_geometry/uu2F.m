% [F,A] = uu2F(u[,mth]) - Fundamental matrix computation
%
% WARNING - DEVELOPMENT CODE, FOR LIBRARY VERSION SEARCH ELSEWHERE
%
% u   = {u1 u2}, image matches u2'*F*u1 = 0
% mth = method ({'HZ','Free'} implicit)
%       mth{1} = normalization
%                'None' = no normalization
%                'HZ' = full affine as in HZ-2003
%                '[-1,1]' = ranges of points are scaled to interval [-1,1]x[-1,1]
%       mth{2} = constraints on F imposed
%                'Free'  = no constraints, i.e. |F|=0 not required (works for 8 and more matches)
%                '|F|=0' = rank two F imposed (works for 7 and more matches)
%                ' '
% F   = Fundamental matrix u2'*F*u1 = 0
% A   = normalization transforms: F = A{2}'*Fn*A{1};  u{2}'*A{2}'*Fn*A{1}*u{1}->0 => Fn
%
% T. Pajdla, pajdla@cvut.cz, 2016-09-11
function [F,A,f] = uu2F(u,mth,testset,cells)
if nargin<3
    testset={NaN};
end
global original_solver;
if nargin<4
    cells=false; % determines whether in Prop6 we return cell array or just array
end
original_solver=false;
focal={NaN};
if nargin>0
    if nargin<2
        mth = {'HZ','Free'};
    end
    if ~iscell(mth)
        mth = {mth 'Free'};
    end
    if numel(mth)<2
        error('uu2F: cellarray mth must have two elements');
    end
    u = cellfunuo(@(x) x(1:2,:),u); % use the first two coordinates
    switch mth{1}
        case 'None'
            A{1} = eye(3); A{2} = A{1};
        case 'HZ'
            [A{1},A{2}] = xy2nxy(u{1},u{2});
        case '[-1,1]'
            A{1} = x2nx(u{1},'[-1,1]');
            A{2} = x2nx(u{2},'[-1,1]');
        otherwise
            error('uu2F: unknown normalization method %s',mth{1});
    end
    % normalize
    x = {A{1}*a2h(u{1}) A{2}*a2h(u{2})};
    switch mth{2}
        case 'Prop6'
            n=size(x{1},2);
            per=nchoosek(1:min(n,8),6);
            f=cell(1,n);
            for j=1:size(per,1)
                x_t = {x{1}(:,per(j,:)) x{2}(:,per(j,:))};
                B = zeros(size(x_t{1},2),9);
                % B * f = 0
                for i=1:size(x_t{1},2)
                    B(i,:) = m2v(x_t{1}(:,i)*x_t{2}(:,i)');
                end
                [~,~,f{j}]=svd(B,0);
            end
        otherwise
            B = zeros(size(x{1},2),9);
            % B * f = 0
            for i=1:size(x{1},2)
                B(i,:) = m2v(x{1}(:,i)*x{2}(:,i)');
            end
            % f is the null space of B
            [~,~,f] = svd(B,0);
    end
    %calculate
    switch mth{2}
        case 'Free'
            if size(B,1)<8
                error('uu2F: mth{2} = ''Free'' needs at least 8 matches');
            end
            f = f(:,end);
            % reformat back
            F = reshape(f,3,3)';
        case '|F|=0'
            % det(F1+t*F2) = a'*[t^3;t^2;t;1]
            % det(t*F1+F2) = a'*[1;t;t^2;t^3]
            % Choose the one with the larger absolute value at the highest power
            % to avoid division by zero and avoid t going to infty
            N{1} = reshape(f(:,end-1),3,3)';
            N{2} = reshape(f(:,end),3,3)';
            a = [det(N{2})
                (det([N{1}(:,1) N{2}(:,[2 3])])-det([N{1}(:,2) N{2}(:,[1 3])])+det([N{1}(:,3) N{2}(:,[1 2])]))
                (det([N{2}(:,1) N{1}(:,[2 3])])-det([N{2}(:,2) N{1}(:,[1 3])])+det([N{2}(:,3) N{1}(:,[1 2])]))
                det(N{1})];
            if abs(a(end))>abs(a(1)) % choose the larger value
                a = a(end:-1:1);
                ix = [1 2]; % det(t*F1+F2) = a'*[1;t;t^2;t^3]
            else
                ix = [2 1]; % det(F1+t*F2) = a'*[t^3;t^2;t;1]
            end
            a = a/a(1); % monic polynomial
            C = [0 0 -a(4);1 0 -a(3);0 1 -a(2)]; % companion matrix
            t = eig(C);
            t = t(abs(imag(t))<eps); % select real solutions
            F = zeros(3,3,numel(t));
            for i=1:numel(t)
                F(:,:,i) = t(i)*N{ix(1)}+N{ix(2)};
            end
        case 'Prop'
            % estimate and use the value of f1/f2 for subsequent
            % opimalization of result
            
            % using third smaller singular value to compensate for one
            % extra equation
            
            %f1/f2 estimated by calling uu2F
            prop=getFProp(u,testset);           
            [F,focal]=propdet2F(f,prop);
        case 'Prop6'
            % same as above, but computes all different 6-subsets solutions
            
            %f1/f2 estimated by calling uu2F
            prop=getFProp(u,testset);
            if cells
                F=cell(1,n);
            else                
                F=[];
            end
            for i=1:n
                if cells
                    [F{i},focal{i}]=propdet2F(f{i},prop);
                else
                    [Ft,~]=propdet2F(f{i},prop);
                    F=cat(3,F,Ft);
                end
            end
        otherwise
            error([mth{2} ' not implemented']);
    end
    % denormalize: u2'*Fa*u1 = u2'*A2'*F*A1*u1 => Fa = A2'*F*A
    switch mth{2}
        case 'Prop6'
            if cells
            for j=1:size(F,2)
                for i=1:size(F{j},3)
                    F{j}(:,:,i) = A{2}'*F{j}(:,:,i)*A{1};
                end
            end
            else
                for i=1:size(F,3)
                    F(:,:,i) = A{2}'*F(:,:,i)*A{1};
                end
            end
        otherwise
            for i=1:size(F,3)
                F(:,:,i) = A{2}'*F(:,:,i)*A{1};
            end
    end
else % unit tests
    % test 1
    X = [0 1 1 0 0 1 2 0
        0 0 1 1 0 0 1 1
        0 0 0 0 1 2 1 2];
    P1 = [1 0 0 1
        0 1 0 0
        0 0 1 1];
    P2 = [1 0 0 0
        0 1 0 1
        0 0 1 1];
    u1 = X2u(X,P1);
    u2 = X2u(X,P2);
    Fo = uu2F({u1,u2},{'[-1,1]','Free'});
    Fo = Fo/norm(Fo);
    F(1) = max(abs(sum(u2.*(Fo*u1))))<1e-8;
    % test 2
    E = E5ptNister([u1(:,1:5);u2(:,1:5)]);
    F(2) = norm(E{end}-Fo/norm(Fo,2),2)<1e-8;
    % test 3
    Fo = uu2F({u1(:,1:8),u2(:,1:8)},{'[-1,1]','|F|=0'});
    for i=1:size(Fo,3)
        Fo(:,:,i) = Fo(:,:,i)/norm(Fo(:,:,i));
        e(i) = max(abs(sum(u2.*(Fo(:,:,i)*u1))));
    end
    F(3) = any(e<1e-10);
    % test 4
    P1 = rand(3,4);
    P2 = rand(3,4);
    u1 = X2u(X,P1);
    u2 = X2u(X,P2);
    Fo = uu2F({u1,u2},{'[-1,1]','Free'});
    Fo = Fo/norm(Fo);
    F(4) = max(abs(sum(u2.*(Fo*u1))))<1e-10;
    % test 5
    Fo = uu2F({u1,u2},{'[-1,1]','|F|=0'});
    for i=1:size(Fo,3)
        Fo(:,:,i) = Fo(:,:,i)/norm(Fo(:,:,i));
        e(i) = max(abs(sum(u2.*(Fo(:,:,i)*u1))));
    end
    F(5) = min(e)<1e-10;
    % test 6 & 7
    P1 = [1 0 0 0
        0 1 0 0
        0 0 1 0];
    P1(:,4) = rand(3,1);
    P2 = [1 0 0 0
        0 1 0 0
        0 0 1 0];
    P2(:,4) = rand(3,1);
    X = rand(3,8);
    u1 = X2u(X,P1);
    u2 = X2u(X,P2);
    Fo = uu2F({u1,u2},{'HZ','Free'});
    Fo = Fo/norm(Fo);
    Fd = uu2F({u1,u2},{'[-1,1]','|F|=0'});
    for i=1:size(Fd,3)
        Fd(:,:,i) = Fd(:,:,i)/norm(Fd(:,:,i));
        e(i) = max(abs(sum(u2.*(Fd(:,:,i)*u1))));
    end
    [~,ie] = min(e);
    Fd = Fd(:,:,ie);
    E = E5ptNister([u1(:,1:5);u2(:,1:5)]);
    F(6) = norm(E{end}/E{end}(1,3)-Fo/Fo(1,3),2)<1e8;
    F(7) = (norm(Fd/Fd(1,3)-Fo/Fo(1,3),2)<1e8) && (min(svd(Fd))<1e-14);
end
end

function  prop=getFProp(u,testset)
global debugg;
% find proportion with the uu2F function.
if size(u{1},2)>7
    Fund=F_features(u{1}, u{2}, 'Free', testset);
else
    Fund=F_features(u{1}, u{2}, '|F|=0', testset);
end
focal=F2f1f2(reshape(Fund,3,3));
prop=abs(focal(2))/abs(focal(1));
if debugg
    focal;
end
end

function [F,focal]=propdet2F(f,prop)
% use proportion and 3 least components of 'f' to find possible Fs.
global original_solver;
N{1} = reshape(f(:,end-2),3,3)';
N{2} = reshape(f(:,end-1),3,3)';
N{3} = reshape(f(:,end),3,3)';
if original_solver    
    %reshaper=@(f,prop) reshape(diag([1 1 1/prop])*reshape(f,3,3,[]),size(f));
    [coef1,coef2,focal]=solver_sw6pt(diag([1 1 1/prop])*N{1},diag([1 1 1/prop])*N{2},diag([1 1 1/prop])*N{3});
else
    [coef1,coef2,focal]=sw6pt_prop_wrap(prop,N{1},N{2},N{3});
end
sieve= abs(imag(focal))<eps; % select real solutions?
focal = focal(sieve);
coef1 = coef1(sieve);
coef2 = coef2(sieve);
focal=sqrt(1./focal); 
F = zeros(3,3,numel(focal));
for i=1:numel(focal)
    F(:,:,i) = coef1(i)*N{1}+coef2(i)*N{2}+N{3};
end
end