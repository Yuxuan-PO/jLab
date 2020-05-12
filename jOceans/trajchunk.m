function[varargout]=trajchunk(varargin)
%TRAJCHUNK  Chunks Lagrangian trajectories based on the Coriolis period.
%
%   TRAJCHUNK is used to split float or drifter data into chunks such that
%   the length of each chunk is a fixed multiple of one over the mean
%   Coriolis frequency. This can be useful in spectral analysis. 
%
%   [NUMO,LATO]=TRAJCHUNK(NUM,LAT,P), where NUM and LAT are date number and
%   latitude for Lagangian float or drifter data, re-organizes these into 
%   chunks such that the average Coriolis frequency f_C in each chunk is at 
%   least P times the Rayleigh frequency f_R for that chunk.
%
%   The Rayleigh frequency is f_R=2*pi/(DT*N), in units of radians per unit 
%   time, where DT is the sample interval and N is the number of samples.
%   The Rayleigh frequency decreases as the chunk length increases.
%
%   The input fields NUM and LAT may either be numerical arrays, or 
%   cell arrays of numerical arrays, e.g. NUM{1}=NUM1, NUM{2}=NUM2, etc.
%
%   The output variables NUM and LAT are cell arrays of numerical arrays, 
%   with each cell being just long enough such that f_C > P * f_R. 
%
%   Trajectories that are not long enough to satisfy this criterion are 
%   discarded, as are short residual segments at the end of trajectories.   
%
%   Each input trajectory is thus split into zero, one, or more than one
%   cells in the output variables.     
%
%   TRAJCHUNK(...,P,LMIN) additionally specifies a mininum number of points
%   LMIN for each chunk.  
%   __________________________________________________________________
%
%   Multiple input / output arguments
%
%   [NUMO,LATO,Y1,Y2,...,YM]=TRAJCHUNK(NUM,LAT,X1,X2,...XM,P) chunks the M
%   input arrays X1, X2,... XM in the same manner, and returns these as Y1,
%   Y2,... YM.  The input variables may either all be numerical arrays of 
%   all the same size, or cell arrays of numerical arrays. 
%
%   In the case of cell array input, some of the XM may be numerical arrays
%   of the same length as the cells NUM and LAT.  The corresponding output 
%   variable will then also be a numerical array.  An example of such a
%   field is the identification number used in FLOATS.MAT and DRIFTERS.MAT. 
%
%   TRAJCHUNK with no output arguments overwrites the original named output
%   variables. 
%   __________________________________________________________________
%   
%   Optional behaviors
%
%   By default, any data in short trajectories for which f_C < P * f_R are 
%   discarded, as are data segments at the end of the trajectories.  
%
%   TRAJCHUNK(...,'keep') keeps these instead.  Short trajectories are 
%   returned in their own chunks, and leftover segments are appended to 
%   the end of the preceding chunk.  
%
%   TRAJCHUNK(...,'full') instead ensures that the output cells span the 
%   full duration of the input fields.  This is done by appending a final 
%   cell having f_C > P * f_R, like the others, but that ends at the final
%   data point, regardless of the degree of overlap with the previous cell.  
%   Data from cells shorter than the specified length are discarded. 
%   __________________________________________________________________
%   
%   Overlap
%
%   TRAJCHUNK(...,'overlap',PCT) outputs chunks with a percentage PCT 
%   overlap.  For example, TRAJCHUNK(...,'overlap',50) outputs chunks that 
%   overlap by 50%.  The default behavior gives chunks with no overlap.
%   __________________________________________________________________   
%
%   See also CELLCHUNK.
%
%   'trajchunk --t' runs a test.
%
%   Usage: [num,lat]=trajchunk(num,lat,P);
%          [num,lat,lon,cv]=trajchunk(num,lat,lon,cv,P);
%          [num,lat,lon,cv]=trajchunk(num,lat,lon,cv,P,lmin);
%          [num,lat,lon,cv]=trajchunk(num,lat,lon,cv,P,'overlap',50);
%          trajchunk(num,lat,lon,cv,P);
%   __________________________________________________________________
%   This is part of JLAB --- type 'help jlab' for more information
%   (C) 2014--2019 J.M. Lilly --- type 'help jlab_license' for details

%   [...,II,KK]=TRAJCHUNK(...) in this case also outputs the indices of
%   the data locations within the input cells.  KK is not a cell array
%   like the other output arguments, but rather a row array of LENGTH(II).

%   [..,II]=TRAJCHUNK(...), with an extra final output argument, 
%   outputs a cell array II of indices to the original time series. 
%
%   As an example, LAT(II{1}) gives the latitudes of the data in the first 
%   cell of the output, LATO{1}.


%   Equivalently, this means that the inertial period 2*pi/f_C is just less
%   than 1/M times the chunk duration DT*N, or 2*pi/f_C < (1/M) * (DT*N). 
%   Thus M inertial oscillations fit into each chunk.
%   Not completely sure about the wording of this due to the definition of 
%   'mean Coriolis frequency' etc.

if strcmpi(varargin{1}, '--t')
    trajchunk_test,return
end

factor=1;
opt='nokeep';     %What to do with leftover points

for i=1:2
    if ischar(varargin{end})
        if strcmpi(varargin{end}(1:3),'kee')||strcmpi(varargin{end}(1:3),'nok')||strcmpi(varargin{end}(1:3),'ful')
            opt=varargin{end};
            varargin=varargin(1:end-1);
        end
    end
    if ischar(varargin{end-1})
        if strcmpi(varargin{end-1}(1:3),'ove')
            factor=1-varargin{end}/100;
            varargin=varargin(1:end-2);
        end
    end
end

if ~iscell(varargin{end-1})&&length(varargin{end-1})==1
    N=varargin{end-1};
    M=varargin{end};
    varargin=varargin(1:end-2);
else
    N=varargin{end};
    M=0;
    varargin=varargin(1:end-1);
end
        
num=varargin{1};
lat=varargin{2};
%Note: leave num and lat as first two entries also
na=length(varargin);

%na,N,M,size(num),size(lat),str,opt
if ~iscell(lat)
    %Create ii index 
    varargin{na+1}=[1:length(lat)]';
    index=trajchunk_index(num,lat,N,M,opt,factor);
    n=0;
    if ~isempty(index)
        for k=1:length(index)
            n=n+1;
            for j=1:na+1
                varargout{j}{n,1}=varargin{j}(index{k});
            end
        end
    end
else            
    %/**************
    %Put numerical array input into cell arrays
    bid=false(size(varargin));
    for i=3:length(bid) %Lat and lon are not allowed to be arrays
        if ~iscell(varargin{i})
            bid(i)=true;
            varargin{i}=celladd(varargin{i},cellmult(0,varargin{1}));
        end
    end
    %\**************
    
%     %Create ii and kk indices
%     for i=1:length(lat)
%         varargin{na+1}{i}=[1:length(lat{i})]';
%         varargin{na+2}{i}=i+0*lat{i};
%     end
    index=[];
    for i=1:length(lat)
        if length(lat)>1000
            if res((i-1)/1000)==0
                disp(['TRAJCHUNK working on cells ' int2str(i) ' to ' int2str(min(i+1000,length(lat))) ' of ' int2str(length(lat)) '.'])
            end
        end
        index{i,1}=trajchunk_index(num{i},lat{i},N,M,opt,factor);
    end     
    n=0;
    for i=1:length(lat)
        if ~isempty(index{i})
            for k=1:length(index{i})
                n=n+1;
                for j=1:na
                    varargout{j}{n,1}=varargin{j}{i}(index{i}{k});
                end
            end
        end
    end
    
    %Return numerical array input back to numerical arrays
    for i=1:length(bid)
        if bid(i)
            varargout{i}=cellfirst(varargout{i});
        end
    end
    
%     %i,j,k,n
%     %Convert cell array kk into numeric array
%     temp=varargout{na+2};
%     varargout{na+2}=zeros(size(varargout{na+1}));
%     for i=1:length(varargout{na+1})
%         varargout{na+2}(i)=temp{i}(1);
%     end
end

eval(to_overwrite(na));

function[index]=trajchunk_index(num,lat,N,M,opt,factor)
if length(num)<2
    index=[];
else  
    dt=num(2)-num(1);
    
    fo=abs(corfreq(lat))*24;
    meanfo=frac(cumsum(fo),[1:length(fo)]');
    fr=frac(2*pi,dt*[1:length(fo)]');
    %aresame(meanfo(end),vmean(fo,1))
    
    bdone=false;
    n=0;
    
    x=[1:length(fo)]';
    index=[];
    while ~bdone
        ii=max(find(N*fr<meanfo,1,'first'),M);
        n=n+1;
        if isempty(ii)||ii>=length(x)
            bdone=1;
        else
            index{n}=x(1:ii);
            %N*fr(ii)<meanfo(ii)
            if ii<length(x)
                x=x(floor(ii*factor)+1:end);
                fo=fo(floor(ii*factor)+1:end);
                %fr=fr(ii+1:end)-fr(ii+1)+frac(2*pi,dt);
                meanfo=frac(cumsum(fo),[1:length(fo)]');
                fr=frac(2*pi,dt*[1:length(fo)]');
                %aresame(meanfo(end),vmean(fo,1))
            end
        end
    end
    
    % if ~isempty(index)
    %     if strcmpi(opt(1:3),'kee')
    %         index{end}=index{end}(1):x(end);
    %     end
    % end
    if strcmpi(opt(1:3),'kee')
        if ~isempty(index)
            index{end}=index{end}(1):x(end);  %Append leftovers
        else
            index{1}=x;  %Keep short segments
        end
    elseif strcmpi(opt(1:3),'ful')
        indexlast=trajchunk_index(num,flipud(lat),N,M,'nokeep',1);
        indexlast=length(lat)-flipud(indexlast{1})+1;
        index{end+1}=indexlast;
        %maxmax(indexlast),length(lat)
    end
end
function[]=trajchunk_test
 

load ebasnfloats

use ebasnfloats
dt=1;
trajchunk(num,lat,lon,32);
meanfo=vmean(abs(corfreq(col2mat(cell2col(lat)))),1)'*24*dt;
fr=frac(2*pi,dt*cellength(lat));
reporttest('TRAJCHUNK no overlap',allall(meanfo>32*fr))
%length(num),length(cell2col(num))

use ebasnfloats
dt=1;
trajchunk(num,lat,lon,32,'overlap',50);
meanfo=vmean(abs(corfreq(col2mat(cell2col(lat)))),1)'*24*dt;
fr=frac(2*pi,dt*cellength(lat));
reporttest('TRAJCHUNK overlap',allall(meanfo>32*fr))

% load drifterheyerdahl
% use drifterheyerdahl
% 
% [numc,latc]=trajchunk(num,lat,60,'overlap',50);
% [~,latc2,numc2]=trajchunk(num,flipud(lat),flipud(num),60,'overlap',50);
% 
% min(cellmin(numc))-min(num)
% max(cellmax(numc))-max(num)
% 
% numc{end+1}=flipud(numc2{1});
% latc{end+1}=flipud(latc2{1});
% 
% for i=1:length(numc)
%     P(i)=sum(abs(corfreq(latc{i}))*24.*(numc{i}-numc{i}(1))/2/pi/24);
% end
% 
% plot(cellmax(numc)-cellmin(numc))
% plot(60*2*pi./(cellmean(cellabs(corfreq(latc)))*24))



%length(num),length(cell2col(num))

% with minimum length 
%
%     trajchunk(num,lat,lon,32,35);
%
% load drifters
% use drifters 
% %trajchunk(num,lat,lon,32,'overlap');
% trajchunk(num,lat,lon,128);
% 
% %meanfo=zeros(length(num),1);
% %fr=zeros(length(num),1);
% 
% %dt=1/4;
% 
% %Same as below but faster
% tic
% meanfo=vmean(abs(corfreq(col2mat(cell2col(lat)))),1)'*24*dt;
% fr=frac(2*pi,dt*cellength(lat));
% toc
% 
% % tic
% % for i=1:length(num)
% %     meanfo(i)=vmean(abs(corfreq(lat{i})),1)*24*dt;
% %     fr(i)=frac(2*pi,dt*length(lat{i}));
% % end
% % toc
% 
% figure,plot(meanfo,'b.'),hold on,plot(32*fr,'ro')
% figure,plot(2*pi./(meanfo/32),'b.'),hold on,plot(2*pi./fr,'ro')
% figure,plot(2*pi./(meanfo/32),2*pi./fr,'ro'),axis equal

