% Existed algorithm for solving the MMV problem based on FOCUSS
% Input: the measurement matrix Y, the sensing matrix Phi, the regularization parameter lambda > 0, generally it is close to the noise variance. 
% In the noiseless cases, simply setting lambda = 1e-10 leads to good performance.
% Output: the reconstructed sparse matrix X, the indexes of nonzero gamma_ind, the final values of all the gamma_ind (including zeros) gamma_est,
% the number of iterations used count
% Written by Zhilin Zhang, David Wipf (05/12/2011): https://github.com/JustinGirard/MatlabCISL/blob/master/MFOCUSS.m
% Reference: 
% [1] S. F. Cotter, B. D. Rao, K. Engan, and K. Kreutz-Delgado. Sparse solutions to linear inverse problems with multiple measurement vectors.
%     IEEE Trans. Signal Process., vol. 53, no. 7, pp. 2477–2488, 2005.
% Latest Revision: 22/07/2024


function [X, gamma_ind, gamma_est, count] = MFOCUSS(Phi, Y, lambda, varargin)

% ============================== Some default parameters ============================== 
%  'p'            : p-norm. p lies in [0,1].  Default value: p = 0.8
%  'PRUNE_GAMMA'  : Threshold for prunning small gamma_i.
%                   In noisy cases, you can set PRUNE_GAMMA = 1e-3 or 1e-4.
%                   In strongly noisy cases (SNR <= 5 dB), suggest to set PRUNE_GAMMA = 0.01;
%                   Default value: MIN_GAMMA = 1e-4. 
%  'PRINT'        : Display flag. If PRINT = 1: show output; If PRINT = 0: supress output
%                   Default value: PRINT = 0

% ==============================  Author ============================== 
%   Zhilin Zhang (z4zhang@ucsd.edu)
%   Mainbody was written by David Wipf

% ==============================  Version ============================== 
%   1.0 (05/12/2011)

[N M] = size(Phi);  % Dimension of the Problem
[N L] = size(Y);  

% Default Control Parameters 
PRUNE_GAMMA = 1e-4;        % threshold for prunning small gamma_i
p           = 0.8;         % p-norm
EPSILON     = 1e-6;        % threshold for stopping iteration. 
MAX_ITERS   = 1000;        % maximum iterations. 
PRINT       = 0;           % not show progress information

% get input argument values
if(mod(length(varargin), 2) == 1)
    error('Optional parameters should always go by pairs\n');
else
    for i = 1:2:(length(varargin) - 1)
        switch lower(varargin{i})
            case 'p'
                p = varargin{i + 1}; 
            case 'prune_gamma'
                PRUNE_GAMMA = varargin{i + 1}; 
            case 'epsilon'   
                EPSILON = varargin{i + 1}; 
            case 'print'    
                PRINT = varargin{i + 1}; 
            case 'max_iters'
                MAX_ITERS = varargin{i + 1};  
            otherwise
                error(['Unrecognized parameter: ''' varargin{i} '''']);
        end
    end
end

if (PRINT) fprintf('\nRunning M-FOCUSS for the MMV Problem...\n'); end

% Initializations 
gamma = ones(M, 1);        % initialization of gamma_i
keep_list = [1:M]';        % record the index of nonzero gamma_i
m = length(keep_list);     % number of nonzero gamma_i
mu = zeros(M, L);          % initialization of the solution matrix
count = 0;                 % record iterations

while (1)

    % =========== Prune weights as their hyperparameters go to zero ===========
    if (min(gamma) < PRUNE_GAMMA)
        index = find(gamma > PRUNE_GAMMA);
        gamma = gamma(index);   
        Phi = Phi(:, index);            % corresponding columns in Phi
        keep_list = keep_list(index);
        m = length(gamma);

        if (m == 0)   break;  end;
    end;

    % ====== Compute new weights ======
    G = repmat(sqrt(gamma)', N, 1);
    PhiG = Phi .* G;
    [U, S, V] = svd(PhiG, 'econ');

    [d1, d2] = size(S);
    if (d1 > 1)     diag_S = diag(S);
    else            diag_S = S(1);      end;

    U_scaled = U(:, 1:min(N, m)) .* repmat((diag_S ./ (diag_S.^2 + sqrt(lambda) + 1e-16))', N, 1);
    Xi = G' .* (V * U_scaled');

    mu_old = mu;
    mu = Xi * Y;

    % *** Update hyperparameters ***
    gamma_old = gamma;
    mu2_bar = sum(abs(mu).^2, 2);
    gamma = (mu2_bar / L).^(1 - p / 2);

    % ========= Check stopping conditions, etc. ========= 
    count = count + 1;
    if (PRINT) disp(['iters: ', num2str(count), '   num coeffs: ', num2str(m), ...
            '   gamma change: ', num2str(max(abs(gamma - gamma_old)))]); end;
    if (count >= MAX_ITERS) break;  end;

    if (size(mu) == size(mu_old))
        dmu = max(max(abs(mu_old - mu)));
        if (dmu < EPSILON)  break;  end;
    end;

end;

gamma_ind = sort(keep_list);
gamma_est = zeros(M, 1);
gamma_est(keep_list, 1) = gamma;  

% expand the final solution
X = zeros(M, L);
X(keep_list, :) = mu;   

if (PRINT) fprintf('\nM-FOCUSS finished !\n'); end
return;
