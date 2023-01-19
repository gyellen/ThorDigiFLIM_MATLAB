function theStruct = parseXML_Thorimage(doc)
% PARSEXML(gy) Convert XML file to a MATLAB structure.
% dbstop if error
if ischar(doc)
    tree = xmlread(doc);
    theStruct = parseChildNodes(tree);
else
    theStruct = parseChildNodes(doc);
end

% ----- Local function PARSECHILDNODES -----
function children = parseChildNodes(theNode)
% Recurse over node children.
children = parseAttributes(theNode); % gy - first add these in
if theNode.hasChildNodes
    childNodes = theNode.getChildNodes;
    numChildNodes = childNodes.getLength;
    for count = 1:numChildNodes
        theChild = childNodes.item(count-1);
        name=char(theChild.getNodeName);
        name=strrep(name,'#','XML_');
        % disp(name);
        if isempty(strfind(name,'XML_'))
            p=parseChildNodes(theChild);
            if isempty(p)
                p=parseAttributes(theChild);
            end
            % disp(p);
%             if isfield(children,name)
%                 if ~iscell(children.(name))
%                     children.(name)={children.(name)};
%                 end
%                 children.(name){end+1}=p;
%             else
%                 children.(name)=p;
%             end
            % NEW code (20141101) for saved values with {n} appended to name
            pos = strfind(name,'ELEMENT___');
            if ~isempty(pos)
                eval(['children{' name(11:end) '}=p;']);
            else
                if ~isfield(children,name)
                    children.(name)=p;
                else
                    % copy the last existing element
                    children.(name)(end+1)=children.(name)(end);
                    % assign all the field values 
                    fn = fieldnames(p);
                    for iField=1:numel(fn)
                        children.(name)(end).(fn{iField}) = p.(fn{iField});
                    end
                end
                %eval(['children.' name '=p;']);
            end
        end
    end
end

% ----- Local function PARSEATTRIBUTES -----
function attributes = parseAttributes(theNode)
% Create attributes structure.

attributes = [];
if theNode.hasAttributes
    theAttributes = theNode.getAttributes;
    numAttributes = theAttributes.getLength;
    
    for count = 1:numAttributes
        attrib = theAttributes.item(count-1);
        val = char(attrib.getValue);
        try
            valnum = eval(val);
            if isnumeric(valnum) && ~isempty(valnum), val=valnum; end
            if islogical(valnum), val=valnum; end
            if strcmp(val,'[]'), val=[]; end
        end
        aname=char(attrib.getName);
        if ~isempty(strfind(aname,'ELEMENT___'))
            % gy: handle the case of cell arrays
            attributes{str2double(aname(11:end))} = val;
        elseif ~isempty(strfind(aname,'CELL___DIMS'))
            % gy: handle the allocation of cell arrays
            if numel(val)==1
                attributes = cell(val,1);
            else
                attributes = cell(val);
            end
        else % ordinary value
            aname(strfind(aname,':'))='_'; % gy: change illegal : character
            attributes.(aname) = val;
        end 
    end
end