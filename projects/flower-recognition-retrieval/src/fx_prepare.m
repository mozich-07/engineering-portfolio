function [T,classes,audit]=fx_prepare(force)
% Immutable data inventory and grouped split. No augmented images in manifest.
if nargin<1, force=false; end
c=fx_config(); cache=fullfile(c.data,'manifest.mat');
if isfile(cache)&&~force, s=load(cache); T=s.T;classes=s.classes;audit=s.audit;return;end
s=load(fullfile(c.data,'imagelabels.mat')); labels=double(s.labels(:));N=numel(labels);
assert(N==8189,'Oxford archive is incomplete');
examples=readtable(fullfile(c.root,'data','category_examples.csv'),'TextType','string');
classes=table((1:102)',strings(102,1),strings(102,1),'VariableNames',{'Id','English','Display'});
for i=1:height(examples)
 k=labels(examples.ImageId(i));classes.English(k)=examples.English(i);
 classes.Display(k)=sprintf('%03d ',k)+examples.Alias(i);
end
assert(all(strlength(classes.English)>0));writetable(classes,fullfile(c.root,'data','classes.csv'),'Encoding','UTF-8');
paths=strings(N,1); hashes=strings(N,1); dh=false(N,64);sizes=zeros(N,2);
for i=1:N
 paths(i)=string(fullfile('data','oxford102','jpg',sprintf('image_%05d.jpg',i)));
 full=fullfile(c.root,paths(i));I=fx_read(full);sizes(i,:)=[size(I,1),size(I,2)];hashes(i)=fx_sha256(full);
 small=imresize(rgb2gray(I),[8 9]);d=small(:,1:8)>small(:,2:9);dh(i,:)=d(:)';
 if mod(i,500)==0,fprintf('Data audit %d/%d\n',i,N);end
end
% Exact duplicates share groups globally. Near duplicates (dHash <= 4) are
% conservatively linked within class; unrelated equal-colour images may link.
parent=(1:N)';links=[];
[~,~,exact]=unique(hashes);
for g=1:max(exact), ids=find(exact==g);parent(ids)=min(ids);end
for k=1:102
 ids=find(labels==k);
 for a=1:numel(ids)
  b=find(sum(xor(dh(ids(a),:),dh(ids(a+1:end),:)),2)<=4)+a;
  for t=b',u=root(ids(a));v=root(ids(t));parent(max(u,v))=min(u,v);links(end+1,:)=[ids(a),ids(t)];end %#ok<AGROW>
 end
end
group=zeros(N,1);for i=1:N,group(i)=root(i);end
include=true(N,1);reason=repmat("",N,1);
for g=unique(group)'
 ids=find(group==g);
 if numel(unique(labels(ids)))>1,include(ids)=false;reason(ids)="conflicting labels";end
end
for g=unique(exact)'
 ids=find(exact==g);if numel(ids)>1,include(ids(2:end))=false;reason(ids(2:end))="exact duplicate";end
end
rng(c.seed);split=repmat("excluded",N,1);
for k=1:102
 groups=unique(group(labels==k & include));groups=groups(randperm(numel(groups)));
 a=floor(.6*numel(groups));b=floor(.8*numel(groups));
 split(include & ismember(group,groups(1:a)))="train";
 split(include & ismember(group,groups(a+1:b)))="validation";
 split(include & ismember(group,groups(b+1:end)))="test";
end
os=load(fullfile(c.data,'setid.mat'));official=strings(N,1);
official(os.trnid)="train";official(os.valid)="validation";official(os.tstid)="test";
T=table((1:N)',paths,labels,hashes,group,split,official,sizes(:,1),sizes(:,2),reason, ...
 'VariableNames',{'ImageId','Path','Label','SHA256','Group','Split','OfficialSplit','Height','Width','Exclusion'});
audit=struct('rawCount',N,'includedCount',sum(include),'excludedCount',sum(~include), ...
 'nearDuplicateLinks',size(links,1),'trainCount',sum(split=="train"),'validationCount',sum(split=="validation"), ...
 'testCount',sum(split=="test"),'classCount',102,'seed',c.seed,'protocol','custom grouped 60/20/20; NOT official benchmark split');
save(cache,'T','classes','audit','dh','-v7');
writetable(T,fullfile(c.results,'dataset_manifest.csv'),'Encoding','UTF-8');
writelines(jsonencode(audit,'PrettyPrint',true),fullfile(c.results,'data_audit.json'));
save(fullfile(c.results,'near_duplicate_links.mat'),'links');
 function r=root(j),r=j;while parent(r)~=r,r=parent(r);end,end
end
