#define _GNU_SOURCE
#include <arpa/inet.h>
#include <ctype.h>
#include <errno.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>
#define PORT 17821
#define ROOT "/var/lib/olympia/addons/airplay2"
#define CFG ROOT "/etc/shairport-sync.conf"
#define LOG ROOT "/www/logs.txt"
#define LIMIT 65536
static int sendall(int f,const char*p,size_t n){while(n){ssize_t k=send(f,p,n,0);if(k<=0)return -1;p+=k;n-=(size_t)k;}return 0;}
static void reply(int f,int code,const char*type,const char*b,const char*o){const char*r=code==200?"OK":code==400?"Bad Request":code==403?"Forbidden":code==404?"Not Found":code==500?"Internal Server Error":"Method Not Allowed";char h[1024];int n=snprintf(h,sizeof h,"HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %zu\r\nCache-Control: no-store\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n%s%s%s\r\n",code,r,type,strlen(b),o?"Access-Control-Allow-Origin: ":"",o?o:"",o?"\r\nVary: Origin\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type, X-HTPlay-Request\r\n":"");sendall(f,h,(size_t)n);sendall(f,b,strlen(b));}
static int origin_ok(const char*o,const char*h){if(!o||!h)return 0;const char*p=strstr(o,"://");if(!p)return 0;p+=3;char a[256],b[256];size_t x=strcspn(p,":/"),y=strcspn(h,":");if(!x||x>=sizeof a||!y||y>=sizeof b)return 0;memcpy(a,p,x);a[x]=0;memcpy(b,h,y);b[y]=0;return !strcasecmp(a,b);}
static int active(const char*u){char c[128];snprintf(c,sizeof c,"systemctl is-active %s >/dev/null 2>&1",u);return system(c)==0;}
static int readfile(const char*p,char*b,size_t n){FILE*f=fopen(p,"rb");if(!f)return -1;size_t z=fread(b,1,n-1,f);b[z]=0;fclose(f);return (int)z;}
static void esc(char*out,size_t cap,const char*in){size_t j=0;for(size_t i=0;in[i]&&j+2<cap;i++){unsigned char c=in[i];if(c=='"'||c=='\\'){out[j++]='\\';out[j++]=(char)c;}else if(c=='\n'){out[j++]='\\';out[j++]='n';}else if(c=='\r'){out[j++]='\\';out[j++]='r';}else if(c>=32)out[j++]=(char)c;}out[j]=0;}
static int setverbosity(int v){char old[32768],next[32768],tmp[128],bak[128];int n=readfile(CFG,old,sizeof old);if(n<0)return -1;char*s=strstr(old,"diagnostics");if(!s)return -2;char*e=strchr(s,'}'),*k=strstr(s,"log_verbosity");if(!e||!k||k>e)return -2;char*q=strchr(k,'=');char*z=q?strchr(q,';'):NULL;if(!q||!z||z>e)return -2;char val[16];snprintf(val,sizeof val,"= %d;",v);size_t pre=(size_t)(q-old),tail=strlen(z+1),vl=strlen(val);if(pre+vl+tail>=sizeof next)return -1;memcpy(next,old,pre);memcpy(next+pre,val,vl);memcpy(next+pre+vl,z+1,tail+1);snprintf(bak,sizeof bak,ROOT "/etc/shairport-sync.conf.bak");snprintf(tmp,sizeof tmp,ROOT "/etc/.shairport-sync.conf.tmp");FILE*f=fopen(bak,"wb");if(!f)return -1;fwrite(old,1,(size_t)n,f);fclose(f);chmod(bak,0600);f=fopen(tmp,"wb");if(!f)return -1;fwrite(next,1,strlen(next),f);if(fclose(f))return -1;chmod(tmp,0600);return rename(tmp,CFG)?-1:0;}
static void handle(int f){char req[LIMIT+1];ssize_t n=recv(f,req,LIMIT,0);if(n<=0)return;req[n]=0;char m[8]={0},path[256]={0},host[256]={0},org[512]={0};sscanf(req,"%7s %255s",m,path);char*p;if((p=strcasestr(req,"\r\nHost:")))sscanf(p+7,"%255[^\r\n]",host);if((p=strcasestr(req,"\r\nOrigin:")))sscanf(p+9,"%511[^\r\n]",org);p=strstr(req,"\r\n\r\n");char*body=p?p+4:"";const char*o=NULL;if(org[0]&&origin_ok(org,host))o=org;if(!strcmp(m,"OPTIONS")){reply(f,o?200:403,"text/plain","",o);return;}if(org[0]&&!o){reply(f,403,"application/json","{\"error\":\"origin rejected\"}",NULL);return;}
if(!strcmp(m,"GET")&&!strcmp(path,"/api/status")){char b[256];snprintf(b,sizeof b,"{\"receiver\":\"%s\",\"nqptp\":\"%s\"}",active("airplay2.service")?"active":"inactive",active("nqptp-airplay2.service")?"active":"inactive");reply(f,200,"application/json",b,o);return;}
if(!strcmp(m,"GET")&&(!strcmp(path,"/api/config")||!strcmp(path,"/api/logs"))){char raw[30000],q[60000],b[61000];const char*file=!strcmp(path,"/api/config")?CFG:LOG;if(readfile(file,raw,sizeof raw)<0)strcpy(raw,"Unavailable.");esc(q,sizeof q,raw);snprintf(b,sizeof b,!strcmp(path,"/api/config")?"{\"config\":\"%s\"}":"{\"logs\":\"%s\"}",q);reply(f,200,"application/json",b,o);return;}
if(!strcmp(m,"POST")&&(!strcmp(path,"/api/start")||!strcmp(path,"/api/stop")||!strcmp(path,"/api/restart"))){const char*act=!strcmp(path,"/api/start")?"start":!strcmp(path,"/api/stop")?"stop":"restart";char cmd[96];snprintf(cmd,sizeof cmd,"systemctl %s airplay2.service >/dev/null 2>&1",act);int r=system(cmd);reply(f,r?500:200,"application/json",r?"{\"error\":\"service operation failed\"}":"{\"ok\":true}",o);return;}
if(!strcmp(m,"POST")&&!strcmp(path,"/api/config/log-verbosity")){char*v=strstr(body,"\"value\"");int x=-1;if(v&&(v=strchr(v,':')))x=atoi(v+1);if(x<0||x>2){reply(f,400,"application/json","{\"error\":\"verbosity must be 0, 1, or 2\"}",o);return;}int r=setverbosity(x);reply(f,r?500:200,"application/json",r?"{\"error\":\"safe config update failed\"}":"{\"ok\":true,\"backup\":\"shairport-sync.conf.bak\",\"restart_required\":true}",o);return;}
reply(f,404,"application/json","{\"error\":\"unknown endpoint\"}",o);}
int main(void){signal(SIGPIPE,SIG_IGN);int s=socket(AF_INET,SOCK_STREAM,0);if(s<0)return 1;int one=1;setsockopt(s,SOL_SOCKET,SO_REUSEADDR,&one,sizeof one);struct sockaddr_in a;memset(&a,0,sizeof a);a.sin_family=AF_INET;a.sin_addr.s_addr=htonl(INADDR_ANY);a.sin_port=htons(PORT);if(bind(s,(struct sockaddr*)&a,sizeof a)||listen(s,8))return 2;for(;;){int f=accept(s,NULL,NULL);if(f<0){if(errno==EINTR)continue;break;}handle(f);close(f);}close(s);return 0;}
