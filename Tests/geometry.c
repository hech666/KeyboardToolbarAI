#include "../Sources/HaogeKeyboardToolbarAIGeometry.h"
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
static long checks;
#define HG_CHECK(x) do {assert(x);++checks;}while(0)
static void check(double w,double h,double left,double right,bool icons,long n,bool has,double y,double rh) {
    HaogeKeyboardToolbarAIGeometry g=haoge_keyboardtoolbarai_geometry(w,h,left,right,icons,n,has,y,rh);
    HG_CHECK(isfinite(g.x)&&isfinite(g.y)&&isfinite(g.width)&&isfinite(g.height)&&isfinite(g.buttonWidth));
    if(w<=1||h<=1||!isfinite(w)||!isfinite(h)||n<1){HG_CHECK(g.count==0);return;}
    HG_CHECK(g.count>=1&&g.count<=n);HG_CHECK(g.x>=0&&g.x<=w);
    HG_CHECK(g.width>=0&&g.x+g.width<=w+0.001);HG_CHECK(g.y>=0&&g.y<=h);
    HG_CHECK(g.height>=0&&g.y+g.height<=h+0.001);HG_CHECK(g.buttonWidth>=0&&g.buttonWidth<=44);
    HG_CHECK(g.count*g.buttonWidth+(g.count-1)*4<=g.width+0.001);
}
int main(void) {
    HaogeKeyboardToolbarAIGeometry g=haoge_keyboardtoolbarai_geometry(390,83,52,338,true,12,true,13,44);
    HG_CHECK(g.count==9);HG_CHECK(g.x==52);HG_CHECK(g.width==286);HG_CHECK(g.y==10);HG_CHECK(g.height==44);
    double widths[]={0,1,2,12,27,28,43,44,100,320,390,430,768,1024};
    double heights[]={0,1,2,12,20,44,83,120};
    for(unsigned i=0;i<sizeof(widths)/sizeof(widths[0]);++i)
      for(unsigned j=0;j<sizeof(heights)/sizeof(heights[0]);++j)
       for(long n=0;n<=18;++n)
        for(int icon=0;icon<=1;++icon){check(widths[i],heights[j],8,widths[i]-8,icon,n,false,0,0);check(widths[i],heights[j],50,widths[i]-50,icon,n,true,-4,44);}
    check(NAN,83,0,300,true,12,false,0,0);check(390,INFINITY,0,300,true,12,false,0,0);
    printf("{\"test\":\"actual shared geometry implementation\",\"assertions\":%ld,\"passed\":true}\n",checks);
    return 0;
}
