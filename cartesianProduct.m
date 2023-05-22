function result = cartesianProduct(sets)
%
%cartesianProduct cartesian product between sets.
%   If sets contains only a single set it is returned as result.
%
%   result = cartesianProduct(sets)
%
%   Inputs:
%       sets        Sets to perform the cartesian product   (cell array)
%
%   Outputs:
%       result      Cartesian product                       (matrix)
%
%   Authors:    Andrea Giusti
%   Date:       2023
%

if length(sets) == 1
    result = cell2mat(sets)';
else
    c = cell(1, numel(sets));
    [c{:}] = ndgrid( sets{:} );
    result = cell2mat( cellfun(@(v)v(:), c, 'UniformOutput',false) );
end

end