% SAVEFAST fast saves of large arrays to .mat files
%
% savefast_safe(filename, varargin)
%
%
% Matlab's 'save' command can be very slow when saving large arrays,
% because by default Matlab attempts to use compression. This function
% provides a much faster alternative, at the cost of larger files.
%
% The syntax is identical to that of the Matlab save command.
%
% Example:
% >> ops = struct('algorithm', 'greedy');
% >> A = int32(randi(20, 1000, 1200, 40));
% >> B = randn(500, 1800, 60);
% >> tic; save /tmp/test ops A B; toc
% Elapsed time is 22.980294 seconds.
% >> tic; savefast /tmp/test ops A B; toc
% Elapsed time is 0.571098 seconds.

% Copyright 2013 by Timothy E. Holy

% Modified to safe version - Michal Odstrcil, 2017

%*-----------------------------------------------------------------------*
%|                                                                       |
%|  Except where otherwise noted, this work is licensed under a          |
%|  Creative Commons Attribution-NonCommercial-ShareAlike 4.0            |
%|  International (CC BY-NC-SA 4.0) license.                             |
%|                                                                       |
%|  Copyright (c) 2017 by Paul Scherrer Institute (http://www.psi.ch)    |
%|                                                                       |
%|       Author: CXS group, PSI                                          |
%*-----------------------------------------------------------------------*
% You may use this code with the following provisions:
%
% If the code is fully or partially redistributed, or rewritten in another
%   computing language this notice should be included in the redistribution.
%
% If this code, or subfunctions or parts of it, is used for research in a 
%   publication or if it is fully or partially rewritten for another 
%   computing language the authors and institution should be acknowledged 
%   in written form in the publication: “Data processing was carried out 
%   using the “cSAXS matlab package” developed by the CXS group,
%   Paul Scherrer Institut, Switzerland.” 
%   Variations on the latter text can be incorporated upon discussion with 
%   the CXS group if needed to more specifically reflect the use of the package 
%   for the published work.
%
% A publication that focuses on describing features, or parameters, that
%    are already existing in the code should be first discussed with the
%    authors.
%   
% This code and subroutines are part of a continuous development, they 
%    are provided “as they are” without guarantees or liability on part
%    of PSI or the authors. It is the user responsibility to ensure its 
%    proper use and the correctness of the results.


% 
% Copyright (c) 2013, Timothy Holy
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
% 
% * Redistributions of source code must retain the above copyright
% notice, this list of conditions and the following disclaimer.
% * Redistributions in binary form must reproduce the above copyright
% notice, this list of conditions and the following disclaimer in
% the documentation and/or other materials provided with the distribution
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.


function savefast_safe(filename, varargin)


    % Append .mat if necessary
    [filepath, filebase, ext] = fileparts(filename);
    if isempty(ext)
        filename = fullfile(filepath, [filebase '.mat']);
    end

    if ~islogical(varargin{end}) || varargin{end} == false
      % ask before overwritting 
        if exist(filename,'file')
            utils.verbose(0,['File ' filename ' exists,' ])
            userans = input(['Do you want to overwrite (y/N)? '],'s');
            if strcmpi(userans,'y')
                utils.verbose(1,['Saving to  ' filename]);
            else
                utils.verbose(1,['Did not save ' filename])
                return
            end
        else
            utils.verbose(1,['Saving to  ' filename]);
        end
    end
    if islogical(varargin{end})
      varargin = varargin(1:end-1); 
    end


    %% ask before rewritting the current file 
    if ~exist(filepath,'dir') && ~isempty(filepath)
        mkdir(filepath); 
    end





  varargin = unique(varargin); 

  % Extract the variable values
  vars = cell(size(varargin));
  for i = 1:numel(vars)
    vars{i} = evalin('caller', varargin{i});
  end
  
  % Separate numeric arrays from the rest
  isnum = cellfun(@(x) isa(x, 'numeric'), vars);
  % remove -struct and -v7 options from the string 
  isopt = cellfun(@(x)strcmp(x(1),'-'), varargin);



    
    
    
  create_dummy = false;
  if all(isnum)
    % Save a dummy variable, just to create the file
    dummy = 0; %#ok<NASGU>
    save(filename, '-v7.3', 'dummy');
    create_dummy = true;
  else
    s = struct;
    for i = 1:numel(isnum)
      if ~isnum(i) && ~isopt(i)
        s.(varargin{i}) = vars{i};
      end
    end
    save(filename, '-v7.3', '-struct', 's');
  end
  
  % Delete the dummy, if necessary, just in case the user supplied a
  % variable called dummy
  if create_dummy
    fid = H5F.open(filename,'H5F_ACC_RDWR','H5P_DEFAULT');
    H5L.delete(fid,'dummy','H5P_DEFAULT');
    H5F.close(fid);
  end
  
  % Save all numeric variables
  for i = 1:numel(isnum)
    if ~isnum(i) || isopt(i)
      continue
    end
    % always assume that single precision is enough for data saving 
    if isa(vars{i}, 'double')
        vars{i} = single(vars{i});
    end

    varname = ['/' varargin{i}];
    if numel(vars{i}) == 0
        warning('Skipping empty variable %s', varname)
        continue
    else
        if isreal(vars{i})
            h5create(filename, varname, size(vars{i}), 'DataType', class(vars{i}));
            h5write(filename, varname, vars{i});
        else
            h5create(filename, [varname,'_r'], size(vars{i}), 'DataType', class(vars{i}));
            h5create(filename, [varname,'_i'], size(vars{i}), 'DataType', class(vars{i}));
            h5write(filename, [varname,'_r'], real(vars{i}));
            h5write(filename, [varname,'_i'], imag(vars{i}));       
        end
    end
end
  
  
  
  
  
  
  
  
  
end

