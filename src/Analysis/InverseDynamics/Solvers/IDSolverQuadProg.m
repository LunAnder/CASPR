% Basic Inverse Dynamics solver for problems in the Quadratic Program form
% This is a well-studied form of inverse dynamics solver for CDPRs.
%
% Author        : Darwin LAU
% Created       : 2015
% Description   : Only a quadratic objective function and linear 
% constraints can be used with this solver. There are multiple types of QP
% solver implementations that can be used with this solver.
classdef IDSolverQuadProg < IDSolverBase
    
    properties (SetAccess = private)
        qp_solver_type
        objective
        constraints = {}
        options
    end
    methods
        function id = IDSolverQuadProg(model, objective, qp_solver_type)
            id@IDSolverBase(model);
            id.objective = objective;
            id.qp_solver_type = qp_solver_type;
            id.active_set = [];
            id.options = [];
        end
        
        function [cable_forces, Q_opt, id_exit_type] = resolveFunction(obj, dynamics)            
            % Form the linear EoM constraint
            % M\ddot{q} + C + G + F_{ext} = -J^T f (constraint)
            [A_eq, b_eq] = IDSolverBase.GetEoMConstraints(dynamics);  
            % Form the lower and upper bound force constraints
            fmin = dynamics.forcesMin;
            fmax = dynamics.forcesMax;
            % Get objective function
            obj.objective.updateObjective(dynamics);
            
            A_ineq = [];
            b_ineq = [];
            for i = 1:length(obj.constraints)
                obj.constraints{i}.updateConstraint(dynamics);
                A_ineq = [A_ineq; obj.constraints{i}.A];
                b_ineq = [b_ineq; obj.constraints{i}.b];                
            end

            % Solves the QP ID different depending on the solver type
            switch (obj.qp_solver_type)
                % Basic version that uses MATLAB's solver
                case ID_QP_SolverType.MATLAB
                    if(isempty(obj.options))
                        obj.options = optimoptions('quadprog', 'Display', 'off', 'MaxIter', 100);
                    end 
                    [cable_forces, id_exit_type] = id_qp_matlab(obj.objective.A, obj.objective.b, A_ineq, b_ineq, A_eq, b_eq, fmin, fmax, obj.f_previous,obj.options);
                % Uses MATLAB solver with a warm start strategy on the
                % active set
                case ID_QP_SolverType.MATLAB_ACTIVE_SET_WARM_START
                    if(isempty(obj.options))
                        obj.options = optimoptions('quadprog', 'Display', 'off', 'MaxIter', 100);
                    end 
                    [cable_forces, id_exit_type,obj.active_set] = id_qp_matlab_active_set_warm_start(obj.objective.A, obj.objective.b, A_ineq, b_ineq, A_eq, b_eq, fmin, fmax, obj.f_previous,obj.active_set,obj.options);
                % Uses the IPOPT algorithm from OptiToolbox
                case ID_QP_SolverType.OPTITOOLBOX_IPOPT
                    if(isempty(obj.options))
                        obj.options = optiset('solver', 'IPOPT', 'maxiter', 100);
                    end 
                    [cable_forces, id_exit_type] = id_qp_opti(obj.objective.A, obj.objective.b, A_ineq, b_ineq, A_eq, b_eq, fmin, fmax, obj.f_previous,obj.options);
                % Uses the OOQP algorithm from the Optitoolbox
                case ID_QP_SolverType.OPTITOOLBOX_OOQP
                    if(isempty(obj.options))
                        obj.options = optiset('solver', 'OOQP', 'maxiter', 100);
                    end                    
                    [cable_forces, id_exit_type] = id_qp_opti(obj.objective.A, obj.objective.b, A_ineq, b_ineq, A_eq, b_eq, fmin, fmax, obj.f_previous,obj.options);
                otherwise
                    error('ID_QP_SolverType type is not defined');
            end
            
            % If there is an error, cable forces will take on the invalid
            % value and Q_opt is infinity
            if (id_exit_type ~= IDSolverExitType.NO_ERROR)
                cable_forces = CableModel.INVALID_FORCE * ones(dynamics.numCables, 1);
                Q_opt = inf;
            % Otherwise valid exit, compute Q_opt using the objective
            else
                Q_opt = obj.objective.evaluateFunction(cable_forces);
            end            
            % Set f_previous, may be useful for some algorithms
            obj.f_previous = cable_forces;
        end
        
        % Helps to add an additional constraint to the QP problem
        function addConstraint(obj, linConstraint)
            obj.constraints{length(obj.constraints)+1} = linConstraint;
        end
    end
    
end

