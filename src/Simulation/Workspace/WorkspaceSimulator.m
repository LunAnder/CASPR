classdef WorkspaceSimulator < MotionSimulator
    %DYNAMICSSIMULATOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        grid            % Grid object for brute force workspace (input)
        workspace       % Final Workspace (output)
        filtered_workspace %Filtered workspace
        WCondition
    end
    
    methods        
        function id = WorkspaceSimulator(w_condition)
            id.WCondition = w_condition;
        end
        
        function run(obj, grid, sdConstructor)
            obj.grid        =   grid;
            obj.workspace   =   repmat([grid.getGridPoint(1);0],1,obj.grid.n_points);
            workspace_count =   0;
            dynamics = sdConstructor();
            % Runs over the grid and evaluates the workspace condition at
            % each point
            for i = 1:round(obj.grid.n_points)
                i
                q = obj.grid.getGridPoint(i);
                dynamics.update(q, zeros(size(q)), zeros(size(q)));
                [inWorkspace,max_vel] = obj.WCondition.evaluate(dynamics);
                if(inWorkspace)
                    workspace_count = workspace_count + 1;
                    obj.workspace(:,workspace_count) = [q;max_vel];
                end
            end
            obj.workspace = obj.workspace(:,1:workspace_count);
        end
        
        function plotWorkspace(obj)
            assert(obj.grid.n_dimensions<=4,'Dimension of Workspace too large to plot');
            figure;  hold on;    axis([-180 180 -180 180]);
            mw = ceil(max(obj.workspace(obj.grid.n_dimensions+1,:).*(obj.workspace(obj.grid.n_dimensions+1,:)~=Inf))+1);
            if(isnan(mw))
                mw = 1;
            end
            mw
            map = colormap(flipud(gray(mw)));
            for i =1:size(obj.workspace,2)
                if(obj.grid.n_dimensions == 2)
                    if(obj.workspace(3,i)==Inf)
                        plot((180/pi)*obj.workspace(1,i),(180/pi)*obj.workspace(2,i),'Color',map(mw,:),'Marker','.')
                    else
                        plot((180/pi)*obj.workspace(1,i),(180/pi)*obj.workspace(2,i),'Color',map(int32(obj.workspace(3,i))+1,:),'Marker','.')
                    end
                elseif(obj.grid.n_dimensions == 3)
                    if(obj.workspace(4,i)==Inf)
                        plot3((180/pi)*obj.workspace(1,i),(180/pi)*obj.workspace(2,i),(180/pi)*obj.workspace(3,i),'Color',map(mw,:),'Marker','.')
                    else
                        plot3((180/pi)*obj.workspace(1,i),(180/pi)*obj.workspace(2,i),(180/pi)*obj.workspace(3,i),'Color',map(int32(obj.workspace(4,i))+1,:),'Marker','.')
                    end
                end
            end 
            colorbar();
        end
        
        function plotWorkspacePlane(obj)
            assert(obj.grid.n_dimensions<=3,'Dimension of Workspace too large to plot');
            figure;  hold on;    axis([-180 180 -180 180]);
            for i =1:size(obj.workspace,2)
                if(obj.grid.n_dimensions == 2)
                    plot((180/pi)*obj.workspace(1,i),(180/pi)*obj.workspace(2,i),'k.')
                elseif(obj.grid.n_dimensions == 3)
                    plot3((180/pi)*obj.workspace(1,i),(180/pi)*obj.workspace(2,i),(180/pi)*obj.workspace(3,i),'k.')
                end
            end 
        end
        
        function plotFilterWorkspace(obj)
            assert(obj.grid.n_dimensions<=3,'Dimension of Workspace too large to plot');
            figure;  hold on;    axis([-180 180 -180 180]);
            for i =1:size(obj.filtered_workspace,2)
                if(obj.grid.n_dimensions == 2)
                    plot((180/pi)*obj.filtered_workspace(1,i),(180/pi)*obj.filtered_workspace(2,i),'k.')
                elseif(obj.grid.n_dimensions == 3)
                    plot3((180/pi)*obj.filtered_workspace(1,i),(180/pi)*obj.filtered_workspace(2,i),(180/pi)*obj.filtered_workspace(3,i),'k.')
                end
            end 
        end
        
        function plotWorkspaceComponents(obj,components)
            assert(obj.grid.n_dimensions<=3,'Dimension of Workspace too large to plot');
            figure;  hold on;    axis([-180 180 -180 180]);
            map = colormap(hsv(max(max(components))));
            for i =1:size(obj.workspace,2)
                if(obj.grid.n_dimensions == 2)
                    plot((180/pi)*obj.workspace(1,i),(180/pi)*obj.workspace(2,i),'Color',map(components(i),:),'Marker','.')
                elseif(obj.grid.n_dimensions == 3)
                    plot3((180/pi)*obj.workspace(1,i),(180/pi)*obj.workspace(2,i),(180/pi)*obj.workspace(3,i),'Color',map(components(i),:),'Marker','.')
                end
            end 
        end
        
        function boundaryFilter(obj)
            obj.filtered_workspace = zeros(size(obj.workspace));
            f_count = 1;
            n_nodes = size(obj.workspace,2);
            tol = 1e-6;
            for i = 1:n_nodes
                c_count = 0;
                j = 1;
                while((j<=n_nodes)&&(c_count<8))
                    % Check if points are connected
                    if((i~=j)&&(obj.WCondition.connected(obj.workspace,i,j,obj.grid)))
%                     if((obj.WCondition.connected(obj.workspace,i,j,obj.grid)))
                        c_count = c_count + 1;
                    end
                    
                    if(c_count == 8)
                        obj.filtered_workspace(:,f_count) = obj.workspace(:,i);
                        f_count = f_count+1;
                    end
                    j = j+1;
                end
                i
            end
            obj.filtered_workspace = obj.filtered_workspace(:,1:f_count-1);
        end
        
        function [adjacency_matrix,laplacian_matrix] = toAdjacencyMatrix(obj)
            % ADD CHECK FOR WHETHER OR NOT SPARSE MATRIX SHOULD BE USED
            % FOR TESTING PURPOSES I AM ONLY CURRENTLY WRITING THIS FOR WCC
            n_nodes = size(obj.workspace,2);
            laplacian_matrix = zeros(n_nodes);
            adjacency_matrix = zeros(n_nodes);
            tol = 1e-6;
            for i = 1:n_nodes
                for j = i+1:n_nodes
                    % Check if points are connected
                    if(obj.WCondition.connected(obj.workspace,i,j,obj.grid))
                        adjacency_matrix(i,j) = 1;
                        adjacency_matrix(j,i) = 1;
                        laplacian_matrix(i,j) = -1;
                        laplacian_matrix(j,i) = -1;
                        laplacian_matrix(i,i) = laplacian_matrix(i,i) + 1;
                        laplacian_matrix(j,j) = laplacian_matrix(j,j) + 1;
                    end
                end
            end
        end
        
        function con_comp = findConnectedComponents(obj,adjacency_matrix)
            components = 0;
            
            con_comp = zeros(size(obj.workspace,2),1);
            
            % Write this better later
            disp('I am here')
            qh_count = 1;
            qe_count = 1;
            queue = con_comp;
            mark = queue;
            for i = 1:size(obj.workspace,2)
                if(con_comp(i) == 0)
                    components = components + 1;
                    mark(i) = 1;
                    queue(qh_count) = i;
                    qe_count = qe_count+1;
                    while((qh_count<qe_count)&&(queue(qh_count) ~= 0))
%                     while(qh_count < 4)
                        % pop vertex from the queue and assign to component
                        con_comp(queue(qh_count)) = components;
                        % add all adjacent elements to the queue that have
                        % not allready been added or popped
                        adj = find(adjacency_matrix(:,queue(qh_count)).*(mark==0)==1);
                        % adjust queue
                        if(size(adj,1)>0)
                            queue(qe_count:qe_count+size(adj,1)-1) = adj;
                            mark(adj) = 1;
                            qe_count = qe_count + size(adj,1);
                        end
                        qh_count = qh_count + 1;
                        
                    end
                else
                    
                end
            end 
        end
        
        %             Components = 0;
% 
% Enumerate all vertices, if for vertex number i, marks[i] == 0 then
% 
%     ++Components;
% 
%     Put this vertex into queue, and 
% 
%     while queue is not empty, 
% 
%         pop vertex v from q
% 
%         marks[v] = Components;
% 
%         Put all adjacent vertices with marks equal to zero into queue.
    end
    
end
