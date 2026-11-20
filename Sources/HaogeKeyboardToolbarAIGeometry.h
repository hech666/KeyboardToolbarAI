#pragma once
#include <math.h>
#include <stdbool.h>
typedef struct {
    double x,y,width,height,buttonWidth;
    long count;
} HaogeKeyboardToolbarAIGeometry;
// Shared by the real toolbar and the host-native C regression tests.
// v2 clamps malformed/narrow dock geometry instead of drawing outside it.
static inline HaogeKeyboardToolbarAIGeometry haoge_keyboardtoolbarai_geometry(
    double dockWidth,double dockHeight,double left,double right,bool icons,
    long requested,bool hasReserved,double reservedY,double reservedHeight) {
    HaogeKeyboardToolbarAIGeometry g={0,0,0,0,0,0};
    if (!isfinite(dockWidth)||!isfinite(dockHeight)||dockWidth<=1||dockHeight<=1||requested<1) return g;
    if (!isfinite(left)||!isfinite(right)) {left=0;right=dockWidth;}
    g.x=fmax(0,left);g.width=fmax(0,fmin(dockWidth,right)-g.x);
    if (g.width<44) {g.x=0;g.width=dockWidth;}
    double minWidth=icons?28:40;
    long fit=(long)floor((g.width+4)/(minWidth+4));
    g.count=requested<(fit>0?fit:1)?requested:(fit>0?fit:1);
    double suggested=(g.width-(g.count-1)*4)/g.count;
    g.buttonWidth=fmin(g.width,fmin(44,fmax(minWidth,suggested)));
    g.height=fmin(44,dockHeight);
    g.y=dockHeight-g.height;
    if (hasReserved && isfinite(reservedY) && isfinite(reservedHeight) && reservedHeight>0) {
        g.height=fmin(reservedHeight,dockHeight);g.y=fmax(0,reservedY-3);
    }
    g.y=fmin(dockHeight,g.y);
    g.height=fmin(g.height,fmax(0,dockHeight-12-g.y));
    return g;
}
