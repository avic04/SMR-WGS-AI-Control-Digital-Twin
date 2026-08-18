function SMR_WGS_AI_Control_Enhanced
% =========================================================================
% SMR_WGS_AI_Control_Enhanced.m
%
% Complete base-MATLAB prototype for:
%   1. Automated engineering validation
%   2. Mechanistic SMR-WGS-flash process model
%   3. PID / Fuzzy-PID / AI-Fuzzy-PID control
%   4. GA-labelled ANN supervisory optimization
%   5. Monte-Carlo robustness analysis
%   6. Multi-objective/Pareto operating-point search
%   7. Executive KPI dashboard
%
% IMPORTANT:
% Numerical kinetics, thermodynamics and economics are prototype values.
% Replace them with literature/plant-validated values before publication
% or industrial use.
%
% KEY MASS-BALANCE FIX:
% SMR is integrated using reaction extent:
%       CH4 + H2O <-> CO + 3H2
% Outlet molar flows are reconstructed from extent, so RK4 numerical
% integration cannot independently clip species and destroy elemental
% conservation.
%
% FLASH FIX:
% Vapor and liquid compositions are obtained directly from the
% Rachford-Rice solution without independently renormalizing both phases.
% =========================================================================

clc;
close all;
rng(11,'twister');

p = make_parameters();

fprintf('\n===============================================================\n');
fprintf(' ENHANCED SMR-WGS-FLASH AI CONTROL DIGITAL TWIN\n');
fprintf('===============================================================\n');

%% 1. Mechanistic model validation
fprintf('\n[1/5] Validating mechanistic process model...\n');
validate_process_model(p);

%% 2. AI supervisory model
fprintf('\n[2/5] Generating GA-labelled data and training ANN...\n');
D = create_training_data(p);
ann = train_ann(D.X,D.Y,p.ann);
fprintf('ANN train RMSE = %.4f K\n',ann.trainRMSE);
fprintf('ANN validation RMSE = %.4f K\n',ann.valRMSE);
fprintf('ANN test RMSE = %.4f K\n',ann.testRMSE);

%% 3. Closed-loop disturbance matrix
fprintf('\n[3/5] Running PID / Fuzzy PID / AI-Fuzzy PID...\n');
results = run_experiment_matrix(p,ann);

%% 4. Automated validation + Monte Carlo
fprintf('\n[4/5] Running automated validation and Monte-Carlo robustness...\n');
validation = validate_all_cases(results,p);
mc = monte_carlo_robustness(p,ann);

%% 5. Multi-objective optimization + dashboard
fprintf('\n[5/5] Multi-objective optimization and KPI dashboard...\n');
pareto = generate_pareto_front(p);
summary = make_summary_table(results,p,validation);
make_dashboard(summary,validation,mc,pareto,p);
make_plots(results,p);

%% Export
assignin('base','SMR_params',p);
assignin('base','SMR_ANN',ann);
assignin('base','SMR_training_data',D);
assignin('base','SMR_results',results);
assignin('base','SMR_validation',validation);
assignin('base','SMR_MonteCarlo',mc);
assignin('base','SMR_Pareto',pareto);
assignin('base','SMR_summary',summary);

fprintf('\n===============================================================\n');
fprintf(' ENHANCED STUDY COMPLETE\n');
fprintf('===============================================================\n');
fprintf('Objects exported to MATLAB workspace:\n');
fprintf(' SMR_params, SMR_ANN, SMR_training_data, SMR_results\n');
fprintf(' SMR_validation, SMR_MonteCarlo, SMR_Pareto, SMR_summary\n');
fprintf('===============================================================\n\n');

end


%% ========================================================================
% PARAMETERS
% =========================================================================
function p = make_parameters()

p.R = 8.314462618;

p.species = {'CH4','H2O','CO','H2','CO2'};
p.MW = [16.043e-3 18.01528e-3 28.010e-3 2.01588e-3 44.0095e-3];

% Rows = C,H,O ; columns = CH4,H2O,CO,H2,CO2
p.elem = [1 0 1 0 1;
          4 2 0 2 0;
          0 1 1 0 2];

p.Cp = [65 43 30 29 50];

% Feed
p.feed.FCH4 = 30;       % mol/s
p.feed.SC = 3.0;        % steam-to-carbon ratio
p.feed.T = 700;         % K
p.feed.P = 20;          % bar

% SMR
p.smr.V = 0.50;
p.smr.Nseg = 24;
p.smr.Tref = 1000;
p.smr.Ea = 105e3;
p.smr.k0 = 0.80;
p.smr.dH = 206e3;       % J/mol, endothermic
p.smr.rhoCp = 2.0e5;
p.smr.UA = 1.5e5;
p.smr.Tenv = 700;
p.smr.Qmin = 0;
p.smr.Qmax = 6.0e6;

% LHHW-style placeholder parameters
p.smr.KCO = 0.02;
p.smr.KH2 = 0.01;
p.smr.KCH4 = 0.005;
p.smr.KH2O = 0.01;
p.smr.Keq = 25;

% WGS
p.wgs.V = 0.25;
p.wgs.Tref = 550;
p.wgs.Ea = 60e3;
p.wgs.k0 = 0.45;
p.wgs.dH = -41.2e3;
p.wgs.rhoCp = 1.5e5;
p.wgs.UA = 1.0e5;
p.wgs.Tenv = 450;
p.wgs.Qmin = -2.0e6;
p.wgs.Qmax = 0;
p.wgs.Keq550 = 8.0;

% Flash
p.flash.Pout = 1.5;
p.flash.K0 = [8.0 0.03 4.0 15.0 0.10];
p.flash.dlnK_dT = [-1800 2500 -1200 -900 2200];

% Engineering constraints
p.bounds.Tsmr = [900 1120];
p.bounds.Twgs = [480 680];
p.bounds.SC = [2.2 4.5];
p.bounds.P = [10 25];
p.bounds.H2purity = 0.70;
p.bounds.CH4conversion = 0.50;
p.bounds.WGSconversion = 0.05;
p.bounds.H2COratio = 3.0;
p.bounds.beta = [0 1];

% PID gains
p.pid.SMR = [1.8e4 1.0e2 1.5e3];
p.pid.WGS = [7.0e3 7.0e1 6.0e2];

% Fuzzy gain scaling
p.fuzzy.eScale = 120;
p.fuzzy.deScale = 25;

% ANN
p.ann.hidden = 16;
p.ann.epochs = 500;
p.ann.lr = 0.004;
p.ann.l2 = 1e-4;
p.ann.trainFraction = 0.70;
p.ann.valFraction = 0.15;

% AI supervisor
p.ai.period = 10;
p.ai.alpha = 0.35;
p.ai.Tsmr = p.bounds.Tsmr;
p.ai.Twgs = p.bounds.Twgs;

% GA
p.ga.Npop = 18;
p.ga.Ngen = 15;
p.ga.elite = 2;
p.ga.crossProb = 0.85;
p.ga.mutProb = 0.25;
p.ga.mutFrac = 0.06;

% Multi-objective search
p.mo.N = 2500;

% Economics
p.econ.H2_INRkg = 350;
p.econ.CH4_INRkg = 45;
p.econ.H2O_INRkg = 0.05;
p.econ.electricity_INRkWh = 8;

% Simulation
p.sim.Ts = 1;
p.sim.tEnd = 180;
p.sim.Tsp = [1020 570];

% Monte Carlo
p.mc.N = 500;
p.mc.sigmaF = 0.05;
p.mc.sigmaT = 15;
p.mc.sigmaP = 1.0;
p.mc.sigmaKin = 0.08;
p.mc.sigmaUA = 0.08;

% Metrics
p.metric.band = 0.02;
p.metric.tail = 10;

p.dist = build_experiment_matrix();

end


%% ========================================================================
% DISTURBANCE MATRIX
% =========================================================================
function d = build_experiment_matrix()

names = {'Nominal','Feed +10%','Feed -10%','Feed T -40 K', ...
    'Feed T +40 K','SMR kinetics -15%','WGS kinetics -15%', ...
    'SMR UA -15%','WGS UA -15%','SMR UA +15%','Combined'};

types = {'none','feed','feed','feedT','feedT','smrKin','wgsKin', ...
    'smrUA','wgsUA','smrUA','combined'};

values = [1 1.10 0.90 -40 40 0.85 0.85 0.85 0.85 1.15 1];

for i = 1:numel(names)
    d(i).id = i;
    d(i).name = names{i};
    d(i).type = types{i};
    d(i).value = values(i);
    d(i).time = 60;
end

end


%% ========================================================================
% NOMINAL MODEL VALIDATION
% =========================================================================
function validate_process_model(p)

z = nominal_z(p);
o = process_model(z,p);

assert(o.valid,'Invalid nominal process result.');
assert(all(isfinite(o.smr.Fout)),'Invalid SMR outlet.');
assert(all(isfinite(o.wgs.Fout)),'Invalid WGS outlet.');
assert(all(isfinite(o.flash.y)),'Invalid flash composition.');
assert(o.flash.beta >= -1e-12 && o.flash.beta <= 1+1e-12, ...
    'Invalid vapor fraction.');

fprintf('\n===============================================================\n');
fprintf(' NOMINAL PROCESS VALIDATION\n');
fprintf('===============================================================\n');
fprintf('SMR conversion = %.6f\n',o.smr.X);
fprintf('WGS conversion = %.6f\n',o.wgs.X);
fprintf('H2 production  = %.6f mol/s\n',o.H2);
fprintf('H2 purity      = %.6f\n',o.flash.y(4));
fprintf('Flash beta     = %.6f\n',o.flash.beta);

tolBalance = 1e-8;

% SMR
bSMR = elemental_balance(o.smr.Fin,o.smr.Fout,p);

fprintf('\nSMR elemental balance:\n');
fprintf('  C balance error = %.3e\n',bSMR.relative(1));
fprintf('  H balance error = %.3e\n',bSMR.relative(2));
fprintf('  O balance error = %.3e\n',bSMR.relative(3));
fprintf('  Maximum error   = %.3e\n',bSMR.maxRelative);

if bSMR.maxRelative >= tolBalance
    fprintf('\nSMR inlet elemental flows:\n');
    disp(bSMR.in.');
    fprintf('SMR outlet elemental flows:\n');
    disp(bSMR.out.');
    fprintf('SMR absolute errors:\n');
    disp(bSMR.absolute.');
    error('SMR elemental balance failed.');
end

% WGS
bWGS = elemental_balance(o.wgs.Fin,o.wgs.Fout,p);

fprintf('\nWGS elemental balance:\n');
fprintf('  C balance error = %.3e\n',bWGS.relative(1));
fprintf('  H balance error = %.3e\n',bWGS.relative(2));
fprintf('  O balance error = %.3e\n',bWGS.relative(3));
fprintf('  Maximum error   = %.3e\n',bWGS.maxRelative);

if bWGS.maxRelative >= tolBalance
    fprintf('\nWGS inlet elemental flows:\n');
    disp(bWGS.in.');
    fprintf('WGS outlet elemental flows:\n');
    disp(bWGS.out.');
    fprintf('WGS absolute errors:\n');
    disp(bWGS.absolute.');
    error('WGS elemental balance failed.');
end

% Flash
bFlash = flash_balance(o.wgs.Fout,o.flash);

fprintf('\nFlash component balance:\n');
fprintf('  Maximum error   = %.3e\n',bFlash.maxRelative);

if bFlash.maxRelative >= tolBalance
    fprintf('\nFlash inlet:\n');
    disp(bFlash.in.');
    fprintf('Flash outlet:\n');
    disp(bFlash.out.');
    fprintf('Flash absolute errors:\n');
    disp(bFlash.absolute.');
    error('Flash component balance failed.');
end

fprintf('\nNominal mechanistic model validation PASSED.\n');

end


function z = nominal_z(p)

z.Tsmr = 1020;
z.Twgs = 570;
z.FCH4 = p.feed.FCH4;
z.FH2O = p.feed.FCH4*p.feed.SC;
z.Tfeed = p.feed.T;
z.P = p.feed.P;
z.Qsmr = 3e6;
z.Qwgs = -2e5;
z.kinSMR = 1;
z.kinWGS = 1;
z.UASMR = 1;
z.UAWGS = 1;
z.capSMR = 1;

end


%% ========================================================================
% TRAINING DATA
% =========================================================================
function D = create_training_data(p)

N = 350;

X = zeros(N,6);
Y = zeros(N,2);

for i = 1:N

    q.FCH4 = p.feed.FCH4*(0.85+0.30*rand);
    q.SC = 2.4+1.6*rand;
    q.Tfeed = 660+80*rand;
    q.P = 15+8*rand;
    q.kinSMR = 0.90+0.20*rand;
    q.kinWGS = 0.90+0.20*rand;
    q.UASMR = 0.90+0.20*rand;
    q.UAWGS = 0.90+0.20*rand;
    q.capSMR = 1;

    X(i,:) = [q.FCH4 q.SC q.Tfeed q.P ...
        930+160*rand 500+120*rand];

    Y(i,:) = ga_optimize_setpoints(q,p);

end

D.X = X;
D.Y = Y;

end


%% ========================================================================
% BASE-MATLAB ANN
% =========================================================================
function ann = train_ann(X,Y,a)

N = size(X,1);

idx = randperm(N);

ntr = max(1,floor(a.trainFraction*N));
nv = max(1,floor(a.valFraction*N));

itr = idx(1:ntr);
iva = idx(ntr+1:min(ntr+nv,N));
ite = idx(min(ntr+nv+1,N):end);

ann.Xmu = mean(X(itr,:),1);
ann.Xsig = std(X(itr,:),0,1);
ann.Xsig(ann.Xsig < 1e-12) = 1;

ann.Ymu = mean(Y(itr,:),1);
ann.Ysig = std(Y(itr,:),0,1);
ann.Ysig(ann.Ysig < 1e-12) = 1;

Xn = normalize_data(X(itr,:),ann.Xmu,ann.Xsig);
Yn = normalize_data(Y(itr,:),ann.Ymu,ann.Ysig);

nin = size(Xn,2);
nh = a.hidden;
nout = 2;

ann.W1 = 0.08*randn(nin,nh);
ann.b1 = zeros(1,nh);
ann.W2 = 0.08*randn(nh,nout);
ann.b2 = zeros(1,nout);

for ep = 1:a.epochs

    A = tanh(Xn*ann.W1 + ann.b1);
    Yhat = A*ann.W2 + ann.b2;

    E = Yhat-Yn;
    dY = 2*E/ntr;

    dW2 = A'*dY + 2*a.l2*ann.W2;
    db2 = sum(dY,1);

    dA = dY*ann.W2';
    dZ = dA.*(1-A.^2);

    dW1 = Xn'*dZ + 2*a.l2*ann.W1;
    db1 = sum(dZ,1);

    ann.W1 = ann.W1-a.lr*dW1;
    ann.b1 = ann.b1-a.lr*db1;
    ann.W2 = ann.W2-a.lr*dW2;
    ann.b2 = ann.b2-a.lr*db2;

end

Ytrain = ann_predict(ann,X(itr,:));
Yval = ann_predict(ann,X(iva,:));
Ytest = ann_predict(ann,X(ite,:));

% Explicit reshape keeps this compatible with older MATLAB releases.
ann.trainRMSE = sqrt(mean((Ytrain(:)-reshape(Y(itr,:),[],1)).^2));
ann.valRMSE = sqrt(mean((Yval(:)-reshape(Y(iva,:),[],1)).^2));
ann.testRMSE = sqrt(mean((Ytest(:)-reshape(Y(ite,:),[],1)).^2));

ann.testIndex = ite;

end


function Y = ann_predict(ann,X)

if isvector(X)
    X = X(:)';
end

Xn = normalize_data(X,ann.Xmu,ann.Xsig);

A = tanh(Xn*ann.W1 + ann.b1);

Yn = A*ann.W2 + ann.b2;

Y = denormalize_data(Yn,ann.Ymu,ann.Ysig);

end


function Xn = normalize_data(X,mu,sig)
Xn = (X-mu)./sig;
end


function X = denormalize_data(Xn,mu,sig)
X = Xn.*sig+mu;
end


%% ========================================================================
% EXPERIMENT MATRIX
% =========================================================================
function results = run_experiment_matrix(p,ann)

controllers = {'PID','FuzzyPID','AIFuzzyPID'};

results = repmat(empty_result(),numel(p.dist),3);

for d = 1:numel(p.dist)
    for c = 1:3
        results(d,c) = simulate_controller( ...
            p,ann,controllers{c},p.dist(d));
    end
end

end


function r = empty_result()

r = struct( ...
    'time',[], ...
    'Tsmr',[], ...
    'Twgs',[], ...
    'SPsmr',[], ...
    'SPwgs',[], ...
    'Qsmr',[], ...
    'Qwgs',[], ...
    'H2',[], ...
    'purity',[], ...
    'energy_kWh_s',[], ...
    'profit',[], ...
    'constraint_violation',[], ...
    'RMSE',NaN, ...
    'IAE',NaN, ...
    'ISE',NaN, ...
    'settlingTime',NaN, ...
    'H2mean',NaN, ...
    'purityMean',NaN, ...
    'energyMean',NaN, ...
    'energyPerKgH2',NaN, ...
    'profitMean',NaN, ...
    'violationIntegral',NaN, ...
    'violationTime',NaN, ...
    'QsmrTV',NaN, ...
    'QwgsTV',NaN, ...
    'QsmrSatTime',NaN, ...
    'QwgsSatTime',NaN, ...
    'controller','', ...
    'disturbance','');

end


%% ========================================================================
% CLOSED LOOP
% =========================================================================
function r = simulate_controller(p,ann,controller,dist)

Ts = p.sim.Ts;
N = floor(p.sim.tEnd/Ts)+1;
t = (0:N-1)';

Tsmr = zeros(N,1);
Twgs = zeros(N,1);
Qsmr = zeros(N,1);
Qwgs = zeros(N,1);

SPsmr = p.sim.Tsp(1)*ones(N,1);
SPwgs = p.sim.Tsp(2)*ones(N,1);

H2 = zeros(N,1);
purity = zeros(N,1);
energy = zeros(N,1);
profit = zeros(N,1);
violation = zeros(N,1);

Tsmr(1) = 950;
Twgs(1) = 530;
Qsmr(1) = 2.5e6;
Qwgs(1) = -2e5;

I1 = 0;
I2 = 0;

e1old = p.sim.Tsp(1)-Tsmr(1);
e2old = p.sim.Tsp(2)-Twgs(1);

superSP = p.sim.Tsp;

q = disturbance_state(p,dist,0);

o = process_model( ...
    make_z(Tsmr(1),Twgs(1),q,Qsmr(1),Qwgs(1)),p);

H2(1) = o.H2;
purity(1) = o.flash.y(4);
energy(1) = power_to_kWhPerS(Qsmr(1),Qwgs(1));
profit(1) = economic_rate(H2(1),q,Qsmr(1),Qwgs(1),p);
violation(1) = state_violation(Tsmr(1),Twgs(1),q,o,p);

for k = 1:N-1

    q = disturbance_state(p,dist,t(k));

    if strcmp(controller,'AIFuzzyPID')

        updateNow = (k == 1) || ...
            mod(k-1,max(1,round(p.ai.period/Ts))) == 0;

        if updateNow

            xin = [q.FCH4 q.SC q.Tfeed q.P Tsmr(k) Twgs(k)];

            proposed = ann_predict(ann,xin);

            proposed(1) = clamp( ...
                proposed(1),p.ai.Tsmr(1),p.ai.Tsmr(2));

            proposed(2) = clamp( ...
                proposed(2),p.ai.Twgs(1),p.ai.Twgs(2));

            superSP = p.ai.alpha*proposed + ...
                (1-p.ai.alpha)*superSP;

        end

        SPsmr(k) = superSP(1);
        SPwgs(k) = superSP(2);

    end

    e1 = SPsmr(k)-Tsmr(k);
    e2 = SPwgs(k)-Twgs(k);

    de1 = (e1-e1old)/Ts;
    de2 = (e2-e2old)/Ts;

    if strcmp(controller,'PID')
        g1 = [1 1 1];
        g2 = [1 1 1];
    else
        g1 = fuzzy_gains(e1,de1,p.fuzzy);
        g2 = fuzzy_gains(e2,de2,p.fuzzy);
    end

    K1 = p.pid.SMR.*g1;
    K2 = p.pid.WGS.*g2;

    I1trial = I1+e1*Ts;
    I2trial = I2+e2*Ts;

    raw1 = 2.5e6 + K1(1)*e1 + ...
        K1(2)*I1trial + K1(3)*de1;

    raw2 = -2e5 + K2(1)*e2 + ...
        K2(2)*I2trial + K2(3)*de2;

    Q1 = clamp(raw1,p.smr.Qmin,p.smr.Qmax);
    Q2 = clamp(raw2,p.wgs.Qmin,p.wgs.Qmax);

    if abs(raw1-Q1) < 1e-12
        I1 = I1trial;
    end

    if abs(raw2-Q2) < 1e-12
        I2 = I2trial;
    end

    Qsmr(k) = Q1;
    Qwgs(k) = Q2;

    z = make_z(Tsmr(k),Twgs(k),q,Q1,Q2);

    x = [Tsmr(k);Twgs(k)];

    k1 = temperature_ode(x,z,p);
    k2 = temperature_ode(x+0.5*Ts*k1,z,p);
    k3 = temperature_ode(x+0.5*Ts*k2,z,p);
    k4 = temperature_ode(x+Ts*k3,z,p);

    xnext = x + Ts*(k1+2*k2+2*k3+k4)/6;

    Tsmr(k+1) = clamp(xnext(1),500,1250);
    Twgs(k+1) = clamp(xnext(2),400,800);

    o = process_model( ...
        make_z(Tsmr(k+1),Twgs(k+1),q,Q1,Q2),p);

    if ~o.valid
        error('Invalid process state at t = %.1f s.',t(k));
    end

    H2(k+1) = o.H2;
    purity(k+1) = o.flash.y(4);
    energy(k+1) = power_to_kWhPerS(Q1,Q2);
    profit(k+1) = economic_rate(H2(k+1),q,Q1,Q2,p);
    violation(k+1) = state_violation( ...
        Tsmr(k+1),Twgs(k+1),q,o,p);

    e1old = e1;
    e2old = e2;

    if strcmp(controller,'AIFuzzyPID')
        SPsmr(k+1) = superSP(1);
        SPwgs(k+1) = superSP(2);
    end

end

Qsmr(end) = Qsmr(end-1);
Qwgs(end) = Qwgs(end-1);

idx = t >= dist.time;

err = sqrt(0.5*((Tsmr-SPsmr).^2+(Twgs-SPwgs).^2));

r = empty_result();

r.time = t;
r.Tsmr = Tsmr;
r.Twgs = Twgs;
r.SPsmr = SPsmr;
r.SPwgs = SPwgs;
r.Qsmr = Qsmr;
r.Qwgs = Qwgs;
r.H2 = H2;
r.purity = purity;
r.energy_kWh_s = energy;
r.profit = profit;
r.constraint_violation = violation;

r.RMSE = sqrt(mean(err(idx).^2));

r.IAE = trapz(t(idx), ...
    abs(Tsmr(idx)-SPsmr(idx))+ ...
    abs(Twgs(idx)-SPwgs(idx)));

r.ISE = trapz(t(idx), ...
    (Tsmr(idx)-SPsmr(idx)).^2+ ...
    (Twgs(idx)-SPwgs(idx)).^2);

r.settlingTime = settling_time( ...
    t(idx),err(idx),p.metric.band,p);

r.H2mean = mean(H2(idx));
r.purityMean = mean(purity(idx));
r.energyMean = mean(energy(idx));

H2kg_s = r.H2mean*p.MW(4);

r.energyPerKgH2 = ...
    (mean(abs(Qsmr(idx))+abs(Qwgs(idx)))/1000/3600) / ...
    max(H2kg_s,eps);

r.profitMean = mean(profit(idx));

r.violationIntegral = trapz(t(idx),violation(idx));
r.violationTime = sum(violation(idx)>0)*Ts;

r.QsmrTV = sum(abs(diff(Qsmr(idx))));
r.QwgsTV = sum(abs(diff(Qwgs(idx))));

r.QsmrSatTime = sum( ...
    abs(Qsmr(idx)-p.smr.Qmax)<1e-6 | ...
    abs(Qsmr(idx)-p.smr.Qmin)<1e-6)*Ts;

r.QwgsSatTime = sum( ...
    abs(Qwgs(idx)-p.wgs.Qmax)<1e-6 | ...
    abs(Qwgs(idx)-p.wgs.Qmin)<1e-6)*Ts;

r.controller = controller;
r.disturbance = dist.name;

end


%% ========================================================================
% PROCESS MODEL
% =========================================================================
function o = process_model(z,p)

smr = smr_pfr(z,p);

wgs = wgs_cstr( ...
    smr.Fout,smr.Tout,z.P,z.Twgs,z.Qwgs,p,z.kinWGS);

flash = flash_separator( ...
    wgs.Fout,z.P,z.Tsmr,p);

o.smr = smr;
o.wgs = wgs;
o.flash = flash;

o.H2 = flash.FV*flash.y(4);

o.valid = ...
    all(isfinite(smr.Fout)) && ...
    all(isfinite(wgs.Fout)) && ...
    all(isfinite(flash.y)) && ...
    isfinite(o.H2) && ...
    o.H2 >= 0;

end


%% ========================================================================
% SMR PFR -- EXTENT BASED
% =========================================================================
function o = smr_pfr(z,p)

FCH4 = max(z.FCH4,0);
FH2O = max(z.FH2O,0);

F0 = [FCH4 FH2O 0 0 0];

xiMax = min(FCH4,FH2O);

state = [0;clamp(z.Tsmr,500,1250)];

h = p.smr.V/p.smr.Nseg;

for n = 1:p.smr.Nseg

    k1 = pfr_ode(state,z,p);
    k2 = pfr_ode(state+0.5*h*k1,z,p);
    k3 = pfr_ode(state+0.5*h*k2,z,p);
    k4 = pfr_ode(state+h*k3,z,p);

    state = state + ...
        h*(k1+2*k2+2*k3+k4)/6;

    state(1) = clamp(state(1),0,xiMax);
    state(2) = clamp(state(2),500,1250);

end

xi = clamp(state(1),0,xiMax);
Tout = clamp(state(2),500,1250);

% CH4 + H2O -> CO + 3H2
nu = [-1 -1 1 3 0];

Fout = F0 + xi*nu;

Fout(abs(Fout)<1e-12) = 0;

if any(Fout < -1e-10)
    error('Negative molar flow detected in SMR PFR.');
end

Fout = max(Fout,0);

o.Fin = F0;
o.Fout = Fout;
o.Tout = Tout;
o.xi = xi;
o.X = xi/max(FCH4,eps);

o.valid = ...
    all(isfinite(Fout)) && ...
    isfinite(Tout) && ...
    xi >= -1e-12 && ...
    xi <= xiMax+1e-12;

end


function dx = pfr_ode(state,z,p)

xi = state(1);
T = clamp(state(2),500,1250);

FCH4 = max(z.FCH4,0);
FH2O = max(z.FH2O,0);

F0 = [FCH4 FH2O 0 0 0];

nu = [-1 -1 1 3 0];

F = F0 + xi*nu;
F = max(F,1e-12);

FT = max(sum(F),1e-12);

y = F/FT;

pp = max(y*z.P,1e-12);

% Reversible LHHW-style expression
Qrxn = (pp(3)*pp(4)^3)/ ...
    max(pp(1)*pp(2),1e-12);

k = p.smr.k0*z.kinSMR* ...
    exp(-p.smr.Ea/p.R*(1/T-1/p.smr.Tref));

den = (1 + ...
    p.smr.KCO*pp(3) + ...
    p.smr.KH2*pp(4) + ...
    p.smr.KCH4*pp(1) + ...
    p.smr.KH2O*pp(2))^2;

rate = k*(pp(1)*pp(2)- ...
    pp(3)*pp(4)^3/max(p.smr.Keq,eps))/ ...
    max(den,eps);

% Forward-only prototype
rate = max(rate,0);

remaining = min(FCH4-xi,FH2O-xi);
rate = min(rate,0.20*max(remaining,0));

CpFlow = max(sum(F.*p.Cp),1);

dT = ...
    (p.smr.UA*z.UASMR*(p.smr.Tenv-T) ...
    - p.smr.dH*rate)/CpFlow;

dx = [rate;dT];

% Avoid unused-variable warning while retaining equilibrium diagnostic.
if ~isfinite(Qrxn)
    dx(:) = 0;
end

end


%% ========================================================================
% WGS CSTR
% =========================================================================
function o = wgs_cstr(Fin,Tin,P,T,Q,p,kfac)

F = max(Fin(:)',0);

FCO = F(3);
FH2O = F(2);
FH2 = F(4);
FCO2 = F(5);

T = clamp(T,400,800);

FT = max(sum(F),1e-12);

k = p.wgs.k0*kfac* ...
    exp(-p.wgs.Ea/p.R*(1/T-1/p.wgs.Tref));

Keq = max(0.1, ...
    p.wgs.Keq550* ...
    exp((-p.wgs.dH/p.R)*(1/T-1/550)));

xiMax = max(0,min(FCO,FH2O));

xi = 0;

tau = p.wgs.V/FT;

for iter = 1:150

    CO = max(FCO-xi,1e-12);
    H2O = max(FH2O-xi,1e-12);
    CO2 = max(FCO2+xi,1e-12);
    H2 = max(FH2+xi,1e-12);

    Qrxn = (CO2*H2)/ ...
        max(CO*H2O,1e-12);

    rate = k*(CO/FT)*(H2O/FT)* ...
        (1-Qrxn/Keq);

    xiNew = clamp(tau*FT*rate,0,xiMax);

    if abs(xiNew-xi)<1e-10
        xi = xiNew;
        break
    end

    xi = 0.7*xi+0.3*xiNew;

end

Fout = F + [0 -xi -xi xi xi];

Fout = max(Fout,0);

CpFlow = max(sum(Fout.*p.Cp),1);

Tout = clamp( ...
    T+(Q-p.wgs.dH*xi)/CpFlow+ ...
    0.15*(Tin-T),400,800);

o.Fin = F;
o.Fout = Fout;
o.Tout = Tout;
o.X = clamp(xi/max(FCO,eps),0,1);
o.xi = xi;

o.valid = ...
    all(isfinite(Fout)) && ...
    isfinite(Tout);

end


%% ========================================================================
% FLASH
% =========================================================================
function o = flash_separator(F,P,T,p)

F = max(F(:)',0);
FT = sum(F);

if FT <= 1e-12

    o.beta = 0;
    o.x = zeros(1,5);
    o.y = zeros(1,5);
    o.FV = 0;
    o.FL = 0;

    return

end

z = F/FT;

K = p.flash.K0 .* ...
    exp(p.flash.dlnK_dT*(1/T-1/1000));

K = K*(p.flash.Pout/P);

K = max(K,1e-12);

RR = @(beta) ...
    sum(z.*(K-1)./(1+beta*(K-1)));

r0 = RR(0);
r1 = RR(1);

if r0 <= 0

    beta = 0;
    x = z;
    y = z;

elseif r1 >= 0

    beta = 1;
    x = z;
    y = z;

else

    lo = 0;
    hi = 1;

    for it = 1:200

        mid = 0.5*(lo+hi);

        if RR(mid)>0
            lo = mid;
        else
            hi = mid;
        end

        if hi-lo < 1e-12
            break
        end

    end

    beta = 0.5*(lo+hi);

    denominator = 1+beta*(K-1);

    x = z./denominator;
    y = K.*x;

end

x = max(x,0);
y = max(y,0);

% Only remove machine-level normalization error.
sx = sum(x);
sy = sum(y);

if abs(sx-1)<1e-10
    x = x/sx;
end

if abs(sy-1)<1e-10
    y = y/sy;
end

FV = beta*FT;
FL = (1-beta)*FT;

o.beta = beta;
o.x = x;
o.y = y;
o.FV = FV;
o.FL = FL;

end


%% ========================================================================
% DYNAMIC TEMPERATURE MODEL
% =========================================================================
function dx = temperature_ode(x,z,p)

Tsmr = clamp(x(1),500,1250);
Twgs = clamp(x(2),400,800);

zz = z;
zz.Tsmr = Tsmr;

smr = smr_pfr(zz,p);

wgs = wgs_cstr( ...
    smr.Fout,smr.Tout,z.P,Twgs,z.Qwgs,p,z.kinWGS);

rSMR = z.FCH4*smr.X;

FTfeed = max(z.FCH4+z.FH2O,1e-12);

CpFeed = max( ...
    (z.FCH4*p.Cp(1)+z.FH2O*p.Cp(2))/FTfeed,1);

dTsmr = ...
    (z.Qsmr + ...
    p.smr.UA*z.UASMR*(p.smr.Tenv-Tsmr) - ...
    p.smr.dH*rSMR + ...
    FTfeed*CpFeed*(z.Tfeed-Tsmr)) / ...
    max(p.smr.rhoCp*z.capSMR,1);

CpWGS = max(sum(wgs.Fout.*p.Cp),1);

dTwgs = ...
    (z.Qwgs + ...
    p.wgs.UA*z.UAWGS*(p.wgs.Tenv-Twgs) - ...
    p.wgs.dH*wgs.xi + ...
    0.20*CpWGS*(smr.Tout-Twgs)) / ...
    max(p.wgs.rhoCp,1);

dx = [dTsmr;dTwgs];

end


%% ========================================================================
% DISTURBANCES
% =========================================================================
function q = disturbance_state(p,d,t)

q.FCH4 = p.feed.FCH4;
q.SC = p.feed.SC;
q.Tfeed = p.feed.T;
q.P = p.feed.P;

q.kinSMR = 1;
q.kinWGS = 1;
q.UASMR = 1;
q.UAWGS = 1;
q.capSMR = 1;

if t < d.time
    return
end

switch d.type

    case 'feed'
        q.FCH4 = p.feed.FCH4*d.value;

    case 'feedT'
        q.Tfeed = p.feed.T+d.value;

    case 'smrKin'
        q.kinSMR = d.value;

    case 'wgsKin'
        q.kinWGS = d.value;

    case 'smrUA'
        q.UASMR = d.value;

    case 'wgsUA'
        q.UAWGS = d.value;

    case 'combined'
        q.FCH4 = 1.10*p.feed.FCH4;
        q.Tfeed = p.feed.T-30;
        q.kinSMR = 0.90;
        q.kinWGS = 0.90;
        q.UASMR = 0.90;
        q.UAWGS = 0.90;

end

end


function z = make_z(Tsmr,Twgs,q,Qsmr,Qwgs)

z.Tsmr = Tsmr;
z.Twgs = Twgs;
z.FCH4 = q.FCH4;
z.FH2O = q.FCH4*q.SC;
z.Tfeed = q.Tfeed;
z.P = q.P;
z.Qsmr = Qsmr;
z.Qwgs = Qwgs;
z.kinSMR = q.kinSMR;
z.kinWGS = q.kinWGS;
z.UASMR = q.UASMR;
z.UAWGS = q.UAWGS;
z.capSMR = q.capSMR;

end


%% ========================================================================
% FUZZY GAIN SCHEDULER
% =========================================================================
function g = fuzzy_gains(e,de,f)

en = clamp(abs(e)/f.eScale,0,1);
den = clamp(abs(de)/f.deScale,0,1);

g = [ ...
    1+0.60*en, ...
    1+0.45*(1-en)*(1-0.50*den), ...
    1+0.35*den];

end


%% ========================================================================
% GA OPERATING POINT
% =========================================================================
function best = ga_optimize_setpoints(q,p)

lo = [p.ai.Tsmr(1) p.ai.Twgs(1)];
hi = [p.ai.Tsmr(2) p.ai.Twgs(2)];

n = p.ga.Npop;

pop = lo + rand(n,2).*(hi-lo);

for gen = 1:p.ga.Ngen

    cost = zeros(n,1);

    for i = 1:n
        cost(i) = economic_objective(pop(i,:),q,p);
    end

    [cost,idx] = sort(cost);
    pop = pop(idx,:);

    newPop = pop(1:p.ga.elite,:);

    while size(newPop,1)<n

        p1 = tournament(pop,cost);
        p2 = tournament(pop,cost);

        if rand<p.ga.crossProb
            a = rand;
            child = a*p1+(1-a)*p2;
        else
            child = p1;
        end

        if rand<p.ga.mutProb
            child = child + ...
                p.ga.mutFrac*(hi-lo).*randn(1,2);
        end

        child = clamp(child,lo,hi);

        newPop(end+1,:) = child; %#ok<AGROW>

    end

    pop = newPop;

end

cost = zeros(n,1);

for i = 1:n
    cost(i) = economic_objective(pop(i,:),q,p);
end

[~,idx] = min(cost);

best = pop(idx,:);

end


function parent = tournament(pop,cost)

i = randi(size(pop,1));
j = randi(size(pop,1));

if cost(i)<=cost(j)
    parent = pop(i,:);
else
    parent = pop(j,:);
end

end


function J = economic_objective(sp,q,p)

o = process_model( ...
    make_z(sp(1),sp(2),q,3e6,-2e5),p);

if ~o.valid
    J = 1e12;
    return
end

profit = economic_rate(o.H2,q,3e6,-2e5,p);

purityPenalty = ...
    5e3*max(0,p.bounds.H2purity-o.flash.y(4))^2;

conversionPenalty = ...
    1e4*max(0,p.bounds.CH4conversion-o.smr.X)^2;

wgsPenalty = ...
    1e4*max(0,p.bounds.WGSconversion-o.wgs.X)^2;

ratio = o.wgs.Fout(4)/max(o.wgs.Fout(3),eps);

ratioPenalty = ...
    1e3*max(0,p.bounds.H2COratio-ratio)^2;

J = -profit + purityPenalty + ...
    conversionPenalty + wgsPenalty + ratioPenalty;

end


%% ========================================================================
% AUTOMATED ENGINEERING VALIDATION
% =========================================================================
function V = validate_all_cases(R,p)

nD = size(R,1);
nC = size(R,2);

rows = nD*nC;

V.rows = repmat(struct(),rows,1);

k = 0;

for d = 1:nD

    for c = 1:nC

        k = k+1;

        r = R(d,c);

        q = disturbance_state( ...
            p,p.dist(d),p.dist(d).time);

        idx = find(r.time>=p.dist(d).time,1);

        if isempty(idx)
            idx = 1;
        end

        j = numel(r.time);

        z = make_z( ...
            r.Tsmr(j), ...
            r.Twgs(j), ...
            q, ...
            r.Qsmr(j), ...
            r.Qwgs(j));

        o = process_model(z,p);

        bSMR = elemental_balance( ...
            o.smr.Fin,o.smr.Fout,p);

        bWGS = elemental_balance( ...
            o.wgs.Fin,o.wgs.Fout,p);

        bFlash = flash_balance( ...
            o.wgs.Fout,o.flash);

        h2co = o.wgs.Fout(4)/ ...
            max(o.wgs.Fout(3),eps);

        allT = ...
            all(r.Tsmr(idx:end)>=p.bounds.Tsmr(1) & ...
            r.Tsmr(idx:end)<=p.bounds.Tsmr(2)) && ...
            all(r.Twgs(idx:end)>=p.bounds.Twgs(1) & ...
            r.Twgs(idx:end)<=p.bounds.Twgs(2));

        allAct = ...
            all(r.Qsmr(idx:end)>=p.smr.Qmin & ...
            r.Qsmr(idx:end)<=p.smr.Qmax) && ...
            all(r.Qwgs(idx:end)>=p.wgs.Qmin & ...
            r.Qwgs(idx:end)<=p.wgs.Qmax);

        flashOK = ...
            o.flash.beta>=p.bounds.beta(1)-1e-10 && ...
            o.flash.beta<=p.bounds.beta(2)+1e-10;

        purityOK = ...
            mean(r.purity(idx:end))>=p.bounds.H2purity;

        smrConvOK = ...
            o.smr.X>=p.bounds.CH4conversion;

        wgsConvOK = ...
            o.wgs.X>=p.bounds.WGSconversion;

        ratioOK = ...
            h2co>=p.bounds.H2COratio;

        quality = purityOK && smrConvOK && ...
            wgsConvOK && ratioOK;

        V.rows(k).disturbance = r.disturbance;
        V.rows(k).controller = r.controller;

        V.rows(k).SMR_C_balance = bSMR.maxRelative;
        V.rows(k).WGS_C_balance = bWGS.maxRelative;
        V.rows(k).Flash_balance = bFlash.maxRelative;

        V.rows(k).TemperatureOK = allT;
        V.rows(k).ActuatorOK = allAct;
        V.rows(k).FlashOK = flashOK;

        V.rows(k).H2Purity = mean(r.purity(idx:end));
        V.rows(k).H2PurityOK = purityOK;

        V.rows(k).CH4Conversion = o.smr.X;
        V.rows(k).CH4ConversionOK = smrConvOK;

        V.rows(k).WGSConversion = o.wgs.X;
        V.rows(k).WGSConversionOK = wgsConvOK;

        V.rows(k).H2COratio = h2co;
        V.rows(k).H2COratioOK = ratioOK;

        V.rows(k).AllOK = ...
            bSMR.maxRelative<1e-8 && ...
            bWGS.maxRelative<1e-8 && ...
            bFlash.maxRelative<1e-8 && ...
            allT && allAct && flashOK && quality;

    end

end

fprintf('\nValidated %d controller/disturbance cases.\n',rows);

passCount = sum([V.rows.AllOK]);

fprintf('Fully passing cases: %d/%d (%.1f%%)\n', ...
    passCount,rows,100*passCount/rows);

end


function b = elemental_balance(Fin,Fout,p)

Fin = Fin(:);
Fout = Fout(:);

Ein = p.elem*Fin;
Eout = p.elem*Fout;

b.in = Ein;
b.out = Eout;

b.absolute = Ein-Eout;

scale = max(abs(Ein),1e-12);

b.relative = b.absolute./scale;

b.maxRelative = max(abs(b.relative));

end


function b = flash_balance(Fin,flash)

vap = flash.FV*flash.y;
liq = flash.FL*flash.x;

b.in = Fin(:);
b.out = vap(:)+liq(:);

b.absolute = b.in-b.out;

scale = max(abs(b.in),1e-12);

b.relative = b.absolute./scale;

b.maxRelative = max(abs(b.relative));

end


%% ========================================================================
% PARETO SEARCH
% =========================================================================
function P = generate_pareto_front(p)

N = p.mo.N;

X = zeros(N,2);
h2 = zeros(N,1);
energy = zeros(N,1);
profit = zeros(N,1);
purity = zeros(N,1);
feasible = false(N,1);

q = struct( ...
    'FCH4',p.feed.FCH4, ...
    'SC',p.feed.SC, ...
    'Tfeed',p.feed.T, ...
    'P',p.feed.P, ...
    'kinSMR',1, ...
    'kinWGS',1, ...
    'UASMR',1, ...
    'UAWGS',1, ...
    'capSMR',1);

for i = 1:N

    X(i,:) = [ ...
        p.bounds.Tsmr(1)+rand*diff(p.bounds.Tsmr), ...
        p.bounds.Twgs(1)+rand*diff(p.bounds.Twgs)];

    o = process_model( ...
        make_z(X(i,1),X(i,2),q,3e6,-2e5),p);

    h2(i) = o.H2*p.MW(4)*3600;

    energy(i) = ...
        (abs(3e6)+abs(-2e5))/1000/3600/ ...
        max(o.H2*p.MW(4),eps);

    profit(i) = ...
        economic_rate(o.H2,q,3e6,-2e5,p);

    purity(i) = o.flash.y(4);

    feasible(i) = ...
        purity(i)>=p.bounds.H2purity && ...
        o.smr.X>=p.bounds.CH4conversion && ...
        o.wgs.X>=p.bounds.WGSconversion && ...
        o.wgs.Fout(4)/max(o.wgs.Fout(3),eps)>=p.bounds.H2COratio;

end

idx = find(feasible);

isPareto = true(size(idx));

for a = 1:numel(idx)

    ia = idx(a);

    for b = 1:numel(idx)

        ib = idx(b);

        if ia==ib
            continue
        end

        dominates = ...
            h2(ib)>=h2(ia) && ...
            profit(ib)>=profit(ia) && ...
            energy(ib)<=energy(ia) && ...
            (h2(ib)>h2(ia) || ...
             profit(ib)>profit(ia) || ...
             energy(ib)<energy(ia));

        if dominates
            isPareto(a) = false;
            break
        end

    end

end

pf = idx(isPareto);

P.Tset = X(pf,:);
P.H2kgph = h2(pf);
P.energyPerKg = energy(pf);
P.profit = profit(pf);
P.purity = purity(pf);
P.n = numel(pf);

fprintf('Pareto-feasible points = %d\n',P.n);

end


%% ========================================================================
% MONTE CARLO
% =========================================================================
function M = monte_carlo_robustness(p,ann)

controllers = {'PID','FuzzyPID','AIFuzzyPID'};

N = p.mc.N;
nc = 3;

pass = false(N,nc);
rmse = zeros(N,nc);
profit = zeros(N,nc);
energy = zeros(N,nc);
purity = zeros(N,nc);
h2 = zeros(N,nc);

for i = 1:N

    q = struct();

    q.FCH4 = p.feed.FCH4*(1+p.mc.sigmaF*randn);
    q.FCH4 = max(q.FCH4,0.2*p.feed.FCH4);

    q.SC = clamp( ...
        p.feed.SC*(1+0.03*randn), ...
        p.bounds.SC(1),p.bounds.SC(2));

    q.Tfeed = p.feed.T+p.mc.sigmaT*randn;

    q.P = clamp( ...
        p.feed.P+p.mc.sigmaP*randn, ...
        p.bounds.P(1),p.bounds.P(2));

    q.kinSMR = max(0.5,1+p.mc.sigmaKin*randn);
    q.kinWGS = max(0.5,1+p.mc.sigmaKin*randn);

    q.UASMR = max(0.5,1+p.mc.sigmaUA*randn);
    q.UAWGS = max(0.5,1+p.mc.sigmaUA*randn);

    q.capSMR = 1;

    for c = 1:nc

        r = simulate_custom_q( ...
            p,ann,controllers{c},q);

        rmse(i,c) = r.RMSE;
        profit(i,c) = r.profitMean;
        energy(i,c) = r.energyPerKgH2;
        purity(i,c) = r.purityMean;
        h2(i,c) = r.H2mean;

        pass(i,c) = r.all_constraints_ok;

    end

end

M.controllers = controllers;
M.pass = pass;
M.RMSE = rmse;
M.profit = profit;
M.energy = energy;
M.purity = purity;
M.H2 = h2;

M.passProbability = mean(pass,1);
M.meanRMSE = mean(rmse,1);
M.meanProfit = mean(profit,1);
M.meanEnergy = mean(energy,1);
M.meanPurity = mean(purity,1);
M.meanH2 = mean(h2,1);

fprintf('\nMonte-Carlo robustness:\n');

for c = 1:nc

    fprintf('%-12s pass = %.1f%% | RMSE = %.3f | energy = %.3f | profit = %.3f\n', ...
        controllers{c}, ...
        100*M.passProbability(c), ...
        M.meanRMSE(c), ...
        M.meanEnergy(c), ...
        M.meanProfit(c));

end

end


%% ========================================================================
% MONTE CARLO CUSTOM SIMULATION
% =========================================================================
function r = simulate_custom_q(p,ann,controller,q)

Ts = p.sim.Ts;
N = floor(p.sim.tEnd/Ts)+1;
t = (0:N-1)';

Tsmr = zeros(N,1);
Twgs = zeros(N,1);
Qsmr = zeros(N,1);
Qwgs = zeros(N,1);

SPsmr = p.sim.Tsp(1)*ones(N,1);
SPwgs = p.sim.Tsp(2)*ones(N,1);

H2 = zeros(N,1);
purity = zeros(N,1);
energy = zeros(N,1);
profit = zeros(N,1);
viol = zeros(N,1);

Tsmr(1) = 950;
Twgs(1) = 530;
Qsmr(1) = 2.5e6;
Qwgs(1) = -2e5;

I1 = 0;
I2 = 0;

e1old = p.sim.Tsp(1)-Tsmr(1);
e2old = p.sim.Tsp(2)-Twgs(1);

superSP = p.sim.Tsp;

for k = 1:N-1

    if strcmp(controller,'AIFuzzyPID')

        if k==1 || ...
                mod(k-1,max(1,round(p.ai.period/Ts)))==0

            pr = ann_predict(ann, ...
                [q.FCH4 q.SC q.Tfeed q.P Tsmr(k) Twgs(k)]);

            pr(1) = clamp( ...
                pr(1),p.ai.Tsmr(1),p.ai.Tsmr(2));

            pr(2) = clamp( ...
                pr(2),p.ai.Twgs(1),p.ai.Twgs(2));

            superSP = p.ai.alpha*pr+ ...
                (1-p.ai.alpha)*superSP;

        end

        SPsmr(k) = superSP(1);
        SPwgs(k) = superSP(2);

    end

    e1 = SPsmr(k)-Tsmr(k);
    e2 = SPwgs(k)-Twgs(k);

    de1 = (e1-e1old)/Ts;
    de2 = (e2-e2old)/Ts;

    if strcmp(controller,'PID')

        g1 = [1 1 1];
        g2 = [1 1 1];

    else

        g1 = fuzzy_gains(e1,de1,p.fuzzy);
        g2 = fuzzy_gains(e2,de2,p.fuzzy);

    end

    K1 = p.pid.SMR.*g1;
    K2 = p.pid.WGS.*g2;

    I1t = I1+e1*Ts;
    I2t = I2+e2*Ts;

    raw1 = 2.5e6+K1(1)*e1+K1(2)*I1t+K1(3)*de1;
    raw2 = -2e5+K2(1)*e2+K2(2)*I2t+K2(3)*de2;

    Q1 = clamp(raw1,p.smr.Qmin,p.smr.Qmax);
    Q2 = clamp(raw2,p.wgs.Qmin,p.wgs.Qmax);

    if abs(raw1-Q1)<1e-12
        I1 = I1t;
    end

    if abs(raw2-Q2)<1e-12
        I2 = I2t;
    end

    Qsmr(k) = Q1;
    Qwgs(k) = Q2;

    z = make_z(Tsmr(k),Twgs(k),q,Q1,Q2);

    x = [Tsmr(k);Twgs(k)];

    a1 = temperature_ode(x,z,p);
    a2 = temperature_ode(x+0.5*Ts*a1,z,p);
    a3 = temperature_ode(x+0.5*Ts*a2,z,p);
    a4 = temperature_ode(x+Ts*a3,z,p);

    xn = x+Ts*(a1+2*a2+2*a3+a4)/6;

    Tsmr(k+1) = clamp(xn(1),500,1250);
    Twgs(k+1) = clamp(xn(2),400,800);

    o = process_model( ...
        make_z(Tsmr(k+1),Twgs(k+1),q,Q1,Q2),p);

    H2(k+1) = o.H2;
    purity(k+1) = o.flash.y(4);
    energy(k+1) = power_to_kWhPerS(Q1,Q2);
    profit(k+1) = economic_rate(H2(k+1),q,Q1,Q2,p);

    viol(k+1) = state_violation( ...
        Tsmr(k+1),Twgs(k+1),q,o,p);

    e1old = e1;
    e2old = e2;

    if strcmp(controller,'AIFuzzyPID')
        SPsmr(k+1) = superSP(1);
        SPwgs(k+1) = superSP(2);
    end

end

Qsmr(end) = Qsmr(end-1);
Qwgs(end) = Qwgs(end-1);

err = sqrt(0.5*((Tsmr-SPsmr).^2+(Twgs-SPwgs).^2));

r = empty_result();

r.time = t;
r.Tsmr = Tsmr;
r.Twgs = Twgs;
r.SPsmr = SPsmr;
r.SPwgs = SPwgs;
r.Qsmr = Qsmr;
r.Qwgs = Qwgs;
r.H2 = H2;
r.purity = purity;
r.energy_kWh_s = energy;
r.profit = profit;
r.constraint_violation = viol;

r.RMSE = sqrt(mean(err.^2));
r.H2mean = mean(H2);
r.purityMean = mean(purity);
r.energyMean = mean(energy);
r.profitMean = mean(profit);

r.violationTime = sum(viol>0)*Ts;

r.energyPerKgH2 = ...
    (mean(abs(Qsmr)+abs(Qwgs))/1000/3600)/ ...
    max(r.H2mean*p.MW(4),eps);

% Full engineering validation for Monte Carlo
final_o = process_model( ...
    make_z(Tsmr(end),Twgs(end),q,Qsmr(end),Qwgs(end)),p);

bSMR = elemental_balance( ...
    final_o.smr.Fin,final_o.smr.Fout,p);

bWGS = elemental_balance( ...
    final_o.wgs.Fin,final_o.wgs.Fout,p);

bFlash = flash_balance( ...
    final_o.wgs.Fout,final_o.flash);

ratio = final_o.wgs.Fout(4)/ ...
    max(final_o.wgs.Fout(3),eps);

tempOK = ...
    all(Tsmr>=p.bounds.Tsmr(1) & ...
        Tsmr<=p.bounds.Tsmr(2)) && ...
    all(Twgs>=p.bounds.Twgs(1) & ...
        Twgs<=p.bounds.Twgs(2));

actOK = ...
    all(Qsmr>=p.smr.Qmin & Qsmr<=p.smr.Qmax) && ...
    all(Qwgs>=p.wgs.Qmin & Qwgs<=p.wgs.Qmax);

flashOK = ...
    final_o.flash.beta>=p.bounds.beta(1) && ...
    final_o.flash.beta<=p.bounds.beta(2);

purityOK = r.purityMean>=p.bounds.H2purity;
smrOK = final_o.smr.X>=p.bounds.CH4conversion;
wgsOK = final_o.wgs.X>=p.bounds.WGSconversion;
ratioOK = ratio>=p.bounds.H2COratio;

r.all_constraints_ok = ...
    bSMR.maxRelative<1e-8 && ...
    bWGS.maxRelative<1e-8 && ...
    bFlash.maxRelative<1e-8 && ...
    tempOK && actOK && flashOK && ...
    purityOK && smrOK && wgsOK && ratioOK;

end


%% ========================================================================
% SUMMARY
% =========================================================================
function S = make_summary_table(R,p,V)

nD = size(R,1);
nC = size(R,2);
N = nD*nC;

Disturbance = cell(N,1);
Controller = cell(N,1);

RMSE = zeros(N,1);
IAE = zeros(N,1);
H2 = zeros(N,1);
Purity = zeros(N,1);
Energy = zeros(N,1);
Profit = zeros(N,1);
Violation = zeros(N,1);
Pass = false(N,1);

row = 0;

for d = 1:nD

    for c = 1:nC

        row = row+1;

        r = R(d,c);
        v = V.rows(row);

        Disturbance{row} = r.disturbance;
        Controller{row} = r.controller;

        RMSE(row) = r.RMSE;
        IAE(row) = r.IAE;
        H2(row) = r.H2mean;
        Purity(row) = r.purityMean;
        Energy(row) = r.energyPerKgH2;
        Profit(row) = r.profitMean;
        Violation(row) = r.violationTime;
        Pass(row) = v.AllOK;

    end

end

S = table( ...
    Disturbance,Controller,RMSE,IAE,H2,Purity, ...
    Energy,Profit,Violation,Pass);

end


%% ========================================================================
% DASHBOARD
% =========================================================================
function make_dashboard(S,V,M,P,p)

controllers = {'PID','FuzzyPID','AIFuzzyPID'};

meanRMSE = zeros(1,3);
meanEnergy = zeros(1,3);
meanProfit = zeros(1,3);
meanPurity = zeros(1,3);
pass = zeros(1,3);

for c = 1:3

    idx = strcmp(S.Controller,controllers{c});

    meanRMSE(c) = mean(S.RMSE(idx));
    meanEnergy(c) = mean(S.Energy(idx));
    meanProfit(c) = mean(S.Profit(idx));
    meanPurity(c) = mean(S.Purity(idx));
    pass(c) = mean(S.Pass(idx));

end

figure('Color','w','Name','Executive KPI Dashboard');

subplot(2,3,1);
bar(meanRMSE);
title('Tracking RMSE');
ylabel('K');
set(gca,'XTickLabel',controllers);
grid on;

subplot(2,3,2);
bar(meanEnergy);
title('Specific Energy');
ylabel('kWh/kg H_2');
set(gca,'XTickLabel',controllers);
grid on;

subplot(2,3,3);
bar(meanProfit);
title('Profit Rate');
ylabel('INR/s');
set(gca,'XTickLabel',controllers);
grid on;

subplot(2,3,4);
bar(100*meanPurity);
title('H_2 Purity');
ylabel('%');
set(gca,'XTickLabel',controllers);
grid on;

subplot(2,3,5);
bar(100*pass);
title('Engineering Validation Pass');
ylabel('%');
set(gca,'XTickLabel',controllers);
grid on;

subplot(2,3,6);
bar(100*M.passProbability);
title('Monte-Carlo Robustness');
ylabel('%');
set(gca,'XTickLabel',controllers);
grid on;

% Improvement relative to PID
pid = 1;

Improvement_RMSE = ...
    100*(meanRMSE(pid)-meanRMSE(:))/max(meanRMSE(pid),eps);

Improvement_Energy = ...
    100*(meanEnergy(pid)-meanEnergy(:))/max(meanEnergy(pid),eps);

Improvement_Profit = ...
    100*(meanProfit(:)-meanProfit(pid))/ ...
    max(abs(meanProfit(pid)),eps);

Improvement_Robustness = ...
    100*(M.passProbability(:)-M.passProbability(pid));

KPI = table( ...
    controllers', ...
    Improvement_RMSE, ...
    Improvement_Energy, ...
    Improvement_Profit, ...
    Improvement_Robustness, ...
    'VariableNames', ...
    {'Controller', ...
    'RMSE_Improvement_pct', ...
    'Energy_Improvement_pct', ...
    'Profit_Improvement_pct', ...
    'Robustness_Improvement_pct'});

fprintf('\n===============================================================\n');
fprintf(' CONTROLLER IMPROVEMENT RELATIVE TO PID\n');
fprintf('===============================================================\n');

disp(KPI);

if P.n>0

    figure('Color','w','Name','Pareto Front');

    scatter(P.energyPerKg,P.H2kgph,30,P.profit,'filled');

    xlabel('Specific energy (kWh/kg H_2)');
    ylabel('H_2 production (kg/h)');
    title('Feasible Pareto Operating Points');

    cb = colorbar;
    ylabel(cb,'Profit (INR/s)');

    grid on;

end

end


%% ========================================================================
% PLOTS
% =========================================================================
function make_plots(R,p)

controllers = {'PID','Fuzzy PID','AI-Fuzzy PID'};
styles = {'-','--','-.'};

figure('Color','w','Name','Temperature Tracking');

subplot(2,1,1);
hold on;

for c = 1:3
    plot(R(1,c).time,R(1,c).Tsmr, ...
        styles{c},'LineWidth',1.4);
end

plot(R(1,1).time,R(1,1).SPsmr, ...
    'k:','LineWidth',1.4);

xlabel('Time (s)');
ylabel('T_{SMR} (K)');
legend([controllers {'Setpoint'}]);
grid on;

subplot(2,1,2);
hold on;

for c = 1:3
    plot(R(1,c).time,R(1,c).Twgs, ...
        styles{c},'LineWidth',1.4);
end

plot(R(1,1).time,R(1,1).SPwgs, ...
    'k:','LineWidth',1.4);

xlabel('Time (s)');
ylabel('T_{WGS} (K)');
legend([controllers {'Setpoint'}]);
grid on;

figure('Color','w','Name','Combined Disturbance');

subplot(2,1,1);
hold on;

for c = 1:3
    plot(R(end,c).time,R(end,c).Tsmr, ...
        styles{c},'LineWidth',1.4);
end

xline(p.dist(end).time,'k--');

xlabel('Time (s)');
ylabel('T_{SMR} (K)');
legend(controllers);
grid on;

subplot(2,1,2);
hold on;

for c = 1:3
    plot(R(end,c).time,R(end,c).Twgs, ...
        styles{c},'LineWidth',1.4);
end

xline(p.dist(end).time,'k--');

xlabel('Time (s)');
ylabel('T_{WGS} (K)');
legend(controllers);
grid on;

end


%% ========================================================================
% ECONOMICS
% =========================================================================
function profit = economic_rate(H2,q,Qsmr,Qwgs,p)

H2Revenue = ...
    H2*p.MW(4)*p.econ.H2_INRkg;

CH4Cost = ...
    q.FCH4*p.MW(1)*p.econ.CH4_INRkg;

H2OCost = ...
    q.FCH4*q.SC*p.MW(2)*p.econ.H2O_INRkg;

energyCost = ...
    power_to_kWhPerS(Qsmr,Qwgs)* ...
    p.econ.electricity_INRkWh;

profit = H2Revenue-CH4Cost-H2OCost-energyCost;

end


function e = power_to_kWhPerS(Q1,Q2)

e = (abs(Q1)+abs(Q2))/1000/3600;

end


%% ========================================================================
% CONSTRAINT VIOLATION
% =========================================================================
function v = state_violation(Tsmr,Twgs,q,o,p)

v = 0;

v = v + max(0,p.bounds.Tsmr(1)-Tsmr);
v = v + max(0,Tsmr-p.bounds.Tsmr(2));

v = v + max(0,p.bounds.Twgs(1)-Twgs);
v = v + max(0,Twgs-p.bounds.Twgs(2));

v = v + max(0,p.bounds.SC(1)-q.SC);
v = v + max(0,q.SC-p.bounds.SC(2));

v = v + max(0,p.bounds.P(1)-q.P);
v = v + max(0,q.P-p.bounds.P(2));

v = v + max(0,p.bounds.H2purity-o.flash.y(4))*100;

v = v + max(0,p.bounds.CH4conversion-o.smr.X)*100;

v = v + max(0,p.bounds.WGSconversion-o.wgs.X)*100;

ratio = o.wgs.Fout(4)/max(o.wgs.Fout(3),eps);

v = v + max(0,p.bounds.H2COratio-ratio);

end


%% ========================================================================
% SETTLING TIME
% =========================================================================
function ts = settling_time(t,e,bandFraction,p)

if numel(t)<2
    ts = t(end);
    return
end

band = bandFraction*sqrt(0.5*( ...
    (p.bounds.Tsmr(2)-p.bounds.Tsmr(1))^2 + ...
    (p.bounds.Twgs(2)-p.bounds.Twgs(1))^2));

inside = abs(e)<=band;

requiredN = max(1, ...
    round(p.metric.tail/(t(2)-t(1))));

ts = t(end);

for k = 1:length(t)-requiredN+1

    if all(inside(k:k+requiredN-1))
        ts = t(k);
        return
    end

end

end


%% ========================================================================
% CLAMP
% =========================================================================
function y = clamp(x,a,b)

y = min(max(x,a),b);

end
