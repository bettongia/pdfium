(function dartProgram(){function copyProperties(a,b){var s=Object.keys(a)
for(var r=0;r<s.length;r++){var q=s[r]
b[q]=a[q]}}function mixinPropertiesHard(a,b){var s=Object.keys(a)
for(var r=0;r<s.length;r++){var q=s[r]
if(!b.hasOwnProperty(q)){b[q]=a[q]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var s=function(){}
s.prototype={p:{}}
var r=new s()
if(!(Object.getPrototypeOf(r)&&Object.getPrototypeOf(r).p===s.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var q=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(q))return true}}catch(p){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var s=Object.create(b.prototype)
copyProperties(a.prototype,s)
a.prototype=s}}function inheritMany(a,b){for(var s=0;s<b.length;s++){inherit(b[s],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var s=a
a[b]=s
a[c]=function(){if(a[b]===s){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var s=a
a[b]=s
a[c]=function(){if(a[b]===s){var r=d()
if(a[b]!==s){A.le(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.w(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.fo(b)
return new s(c,this)}:function(){if(s===null)s=A.fo(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.fo(a).prototype
return s}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var s=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var r=staticTearOffGetter(s)
a[b]=r}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var s=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var r=instanceTearOffGetter(c,s)
a[b]=r}function setOrUpdateInterceptorsByTag(a){var s=v.interceptorsByTag
if(!s){v.interceptorsByTag=a
return}copyProperties(a,s)}function setOrUpdateLeafTags(a){var s=v.leafTags
if(!s){v.leafTags=a
return}copyProperties(a,s)}function updateTypes(a){var s=v.types
var r=s.length
s.push.apply(s,a)
return r}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var s=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},r=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:s(0,0,null,["$0"],0),_instance_1u:s(0,1,null,["$1"],0),_instance_2u:s(0,2,null,["$2"],0),_instance_0i:s(1,0,null,["$0"],0),_instance_1i:s(1,1,null,["$1"],0),_instance_2i:s(1,2,null,["$2"],0),_static_0:r(0,null,["$0"],0),_static_1:r(1,null,["$1"],0),_static_2:r(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
ft(a,b,c,d){return{i:a,p:b,e:c,x:d}},
eU(a){var s,r,q,p,o,n=a[v.dispatchPropertyName]
if(n==null)if($.fr==null){A.l4()
n=a[v.dispatchPropertyName]}if(n!=null){s=n.p
if(!1===s)return n.i
if(!0===s)return a
r=Object.getPrototypeOf(a)
if(s===r)return n.i
if(n.e===r)throw A.h(A.hg("Return interceptor for "+A.e(s(a,n))))}q=a.constructor
if(q==null)p=null
else{o=$.eg
if(o==null)o=$.eg=v.getIsolateTag("_$dart_js")
p=q[o]}if(p!=null)return p
p=A.l9(a)
if(p!=null)return p
if(typeof a=="function")return B.G
s=Object.getPrototypeOf(a)
if(s==null)return B.u
if(s===Object.prototype)return B.u
if(typeof q=="function"){o=$.eg
if(o==null)o=$.eg=v.getIsolateTag("_$dart_js")
Object.defineProperty(q,o,{value:B.m,enumerable:false,writable:true,configurable:true})
return B.m}return B.m},
iP(a,b){if(a<0||a>4294967295)throw A.h(A.V(a,0,4294967295,"length",null))
return J.iQ(new Array(a),b)},
fH(a,b){if(a<0)throw A.h(A.aF("Length must be a non-negative integer: "+a,null))
return A.w(new Array(a),b.h("v<0>"))},
iQ(a,b){var s=A.w(a,b.h("v<0>"))
s.$flags=1
return s},
fJ(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
iS(a,b){var s,r
for(s=a.length;b<s;){r=a.charCodeAt(b)
if(r!==32&&r!==13&&!J.fJ(r))break;++b}return b},
iT(a,b){var s,r,q
for(s=a.length;b>0;b=r){r=b-1
if(!(r<s))return A.c(a,r)
q=a.charCodeAt(r)
if(q!==32&&q!==13&&!J.fJ(q))break}return b},
bc(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.bj.prototype
return J.bJ.prototype}if(typeof a=="string")return J.aN.prototype
if(a==null)return J.bI.prototype
if(typeof a=="boolean")return J.cJ.prototype
if(Array.isArray(a))return J.v.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ai.prototype
if(typeof a=="symbol")return J.bl.prototype
if(typeof a=="bigint")return J.bk.prototype
return a}if(a instanceof A.o)return a
return J.eU(a)},
cu(a){if(typeof a=="string")return J.aN.prototype
if(a==null)return a
if(Array.isArray(a))return J.v.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ai.prototype
if(typeof a=="symbol")return J.bl.prototype
if(typeof a=="bigint")return J.bk.prototype
return a}if(a instanceof A.o)return a
return J.eU(a)},
aC(a){if(a==null)return a
if(Array.isArray(a))return J.v.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ai.prototype
if(typeof a=="symbol")return J.bl.prototype
if(typeof a=="bigint")return J.bk.prototype
return a}if(a instanceof A.o)return a
return J.eU(a)},
l0(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.bj.prototype
return J.bJ.prototype}if(a==null)return a
if(!(a instanceof A.o))return J.b2.prototype
return a},
fq(a){if(typeof a=="string")return J.aN.prototype
if(a==null)return a
if(!(a instanceof A.o))return J.b2.prototype
return a},
i4(a){if(a==null)return a
if(typeof a!="object"){if(typeof a=="function")return J.ai.prototype
if(typeof a=="symbol")return J.bl.prototype
if(typeof a=="bigint")return J.bk.prototype
return a}if(a instanceof A.o)return a
return J.eU(a)},
d(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.bc(a).n(a,b)},
iq(a){if(typeof a=="number")return-a
return J.l0(a).aQ(a)},
dx(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string"||A.l7(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.cu(a).k(a,b)},
bh(a,b,c){return J.aC(a).q(a,b,c)},
a4(a,b){return J.aC(a).u(a,b)},
fv(a,b,c){return J.i4(a).aE(a,b,c)},
fw(a,b){return J.aC(a).G(a,b)},
i(a){return J.bc(a).gm(a)},
ir(a){return J.cu(a).gB(a)},
is(a){return J.cu(a).gM(a)},
cw(a){return J.aC(a).gC(a)},
Q(a){return J.cu(a).gp(a)},
it(a){return J.bc(a).gD(a)},
iu(a,b){return J.aC(a).bo(a,b)},
iv(a,b,c){return J.aC(a).Y(a,b,c)},
fx(a,b){return J.fq(a).aT(a,b)},
iw(a,b,c){return J.i4(a).a1(a,b,c)},
fy(a,b){return J.fq(a).aU(a,b)},
ap(a){return J.bc(a).i(a)},
ix(a){return J.fq(a).by(a)},
cH:function cH(){},
cJ:function cJ(){},
bI:function bI(){},
bL:function bL(){},
ar:function ar(){},
d3:function d3(){},
b2:function b2(){},
ai:function ai(){},
bk:function bk(){},
bl:function bl(){},
v:function v(a){this.$ti=a},
cI:function cI(){},
dE:function dE(a){this.$ti=a},
aG:function aG(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
bK:function bK(){},
bj:function bj(){},
bJ:function bJ(){},
aN:function aN(){}},A={f3:function f3(){},
fD(a,b,c){if(t.V.b(a))return new A.c7(a,b.h("@<0>").t(c).h("c7<1,2>"))
return new A.aH(a,b.h("@<0>").t(c).h("aH<1,2>"))},
k(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
ab(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
eM(a,b,c){return a},
fs(a){var s,r
for(s=$.a0.length,r=0;r<s;++r)if(a===$.a0[r])return!0
return!1},
iW(a,b,c,d){if(t.V.b(a))return new A.bG(a,b,c.h("@<0>").t(d).h("bG<1,2>"))
return new A.aQ(a,b,c.h("@<0>").t(d).h("aQ<1,2>"))},
az:function az(){},
bC:function bC(a,b){this.a=a
this.$ti=b},
aH:function aH(a,b){this.a=a
this.$ti=b},
c7:function c7(a,b){this.a=a
this.$ti=b},
c6:function c6(){},
bD:function bD(a,b){this.a=a
this.$ti=b},
aI:function aI(a,b){this.a=a
this.$ti=b},
dA:function dA(a,b){this.a=a
this.b=b},
cO:function cO(a){this.a=a},
cB:function cB(a){this.a=a},
dR:function dR(){},
l:function l(){},
B:function B(){},
aP:function aP(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aQ:function aQ(a,b,c){this.a=a
this.b=b
this.$ti=c},
bG:function bG(a,b,c){this.a=a
this.b=b
this.$ti=c},
bQ:function bQ(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
r:function r(a,b,c){this.a=a
this.b=b
this.$ti=c},
c3:function c3(a,b,c){this.a=a
this.b=b
this.$ti=c},
c4:function c4(a,b,c){this.a=a
this.b=b
this.$ti=c},
T:function T(){},
c1:function c1(){},
bv:function bv(){},
cq:function cq(){},
ib(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
l7(a,b){var s
if(b!=null){s=b.x
if(s!=null)return s}return t.da.b(a)},
e(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.ap(a)
return s},
d5(a){var s,r=$.h2
if(r==null)r=$.h2=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
j_(a,b){var s,r=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(r==null)return null
if(3>=r.length)return A.c(r,3)
s=r[3]
if(s!=null)return parseInt(a,10)
if(r[2]!=null)return parseInt(a,16)
return null},
d6(a){var s,r,q,p
if(a instanceof A.o)return A.a_(A.be(a),null)
s=J.bc(a)
if(s===B.F||s===B.H||t.cr.b(a)){r=B.n(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.a_(A.be(a),null)},
h9(a){var s,r,q
if(a==null||typeof a=="number"||A.fj(a))return J.ap(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.aq)return a.i(0)
if(a instanceof A.Z)return a.aC(!0)
s=$.ip()
for(r=0;r<1;++r){q=s[r].bz(a)
if(q!=null)return q}return"Instance of '"+A.d6(a)+"'"},
h1(a){var s,r,q,p,o=a.length
if(o<=500)return String.fromCharCode.apply(null,a)
for(s="",r=0;r<o;r=q){q=r+500
p=q<o?q:o
s+=String.fromCharCode.apply(null,a.slice(r,p))}return s},
j0(a){var s,r,q,p=A.w([],t.t)
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.cv)(a),++r){q=a[r]
if(!A.eD(q))throw A.h(A.ct(q))
if(q<=65535)B.d.u(p,q)
else if(q<=1114111){B.d.u(p,55296+(B.c.l(q-65536,10)&1023))
B.d.u(p,56320+(q&1023))}else throw A.h(A.ct(q))}return A.h1(p)},
ha(a){var s,r,q
for(s=a.length,r=0;r<s;++r){q=a[r]
if(!A.eD(q))throw A.h(A.ct(q))
if(q<0)throw A.h(A.ct(q))
if(q>65535)return A.j0(a)}return A.h1(a)},
j1(a,b,c){var s,r,q,p
if(c<=500&&b===0&&c===a.length)return String.fromCharCode.apply(null,a)
for(s=b,r="";s<c;s=q){q=s+500
p=q<c?q:c
r+=String.fromCharCode.apply(null,a.subarray(s,p))}return r},
O(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.l(s,10)|55296)>>>0,s&1023|56320)}throw A.h(A.V(a,0,1114111,null,null))},
j3(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
if(0<=a&&a<100){a+=400
p-=4800}s=B.c.a_(h,1000)
r=Date.UTC(a,p,c,d,e,f,g+B.c.O(h-s,1000))
q=!0
if(!isNaN(r))if(!(r<-864e13))if(!(r>864e13))q=r===864e13&&s!==0
if(q)return null
return r},
bt(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
d4(a){var s=A.bt(a).getUTCFullYear()+0
return s},
h7(a){var s=A.bt(a).getUTCMonth()+1
return s},
h3(a){var s=A.bt(a).getUTCDate()+0
return s},
h4(a){var s=A.bt(a).getUTCHours()+0
return s},
h6(a){var s=A.bt(a).getUTCMinutes()+0
return s},
h8(a){var s=A.bt(a).getUTCSeconds()+0
return s},
h5(a){var s=A.bt(a).getUTCMilliseconds()+0
return s},
iZ(a){var s=a.$thrownJsError
if(s==null)return null
return A.bd(s)},
j2(a,b){var s
if(a.$thrownJsError==null){s=new Error()
A.K(a,s)
a.$thrownJsError=s
s.stack=b.i(0)}},
S(a){throw A.h(A.ct(a))},
c(a,b){if(a==null)J.Q(a)
throw A.h(A.dv(a,b))},
dv(a,b){var s,r="index"
if(!A.eD(b))return new A.a2(!0,b,r,null)
s=J.Q(a)
if(b<0||b>=s)return A.f1(b,s,a,r)
return A.hb(b,r)},
kL(a,b,c){if(a<0||a>c)return A.V(a,0,c,"start",null)
if(b!=null)if(b<a||b>c)return A.V(b,a,c,"end",null)
return new A.a2(!0,b,"end",null)},
ct(a){return new A.a2(!0,a,null,null)},
h(a){return A.K(a,new Error())},
K(a,b){var s
if(a==null)a=new A.al()
b.dartException=a
s=A.lf
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
lf(){return J.ap(this.dartException)},
a1(a,b){throw A.K(a,b==null?new Error():b)},
aE(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.a1(A.jK(a,b,c),s)},
jK(a,b,c){var s,r,q,p,o,n,m,l,k
if(typeof b=="string")s=b
else{r="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
q=r.length
p=b
if(p>q){c=p/q|0
p%=q}s=r[p]}o=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
n=t.j.b(a)?"list":"ByteData"
m=a.$flags|0
l="a "
if((m&4)!==0)k="constant "
else if((m&2)!==0){k="unmodifiable "
l="an "}else k=(m&1)!==0?"fixed-length ":""
return new A.c2("'"+s+"': Cannot "+o+" "+l+k+n)},
cv(a){throw A.h(A.aJ(a))},
am(a){var s,r,q,p,o,n
a=A.lc(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.w([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.dT(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
dU(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
hf(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
f4(a,b){var s=b==null,r=s?null:b.method
return new A.cL(a,r,s?null:b.receiver)},
af(a){var s
if(a==null)return new A.dK(a)
if(a instanceof A.bH){s=a.a
return A.aD(a,s==null?A.bx(s):s)}if(typeof a!=="object")return a
if("dartException" in a)return A.aD(a,a.dartException)
return A.kz(a)},
aD(a,b){if(t.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
kz(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.l(r,16)&8191)===10)switch(q){case 438:return A.aD(a,A.f4(A.e(s)+" (Error "+q+")",null))
case 445:case 5007:A.e(s)
return A.aD(a,new A.bV())}}if(a instanceof TypeError){p=$.id()
o=$.ie()
n=$.ig()
m=$.ih()
l=$.ik()
k=$.il()
j=$.ij()
$.ii()
i=$.io()
h=$.im()
g=p.H(s)
if(g!=null)return A.aD(a,A.f4(A.ao(s),g))
else{g=o.H(s)
if(g!=null){g.method="call"
return A.aD(a,A.f4(A.ao(s),g))}else if(n.H(s)!=null||m.H(s)!=null||l.H(s)!=null||k.H(s)!=null||j.H(s)!=null||m.H(s)!=null||i.H(s)!=null||h.H(s)!=null){A.ao(s)
return A.aD(a,new A.bV())}}return A.aD(a,new A.db(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.c_()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.aD(a,new A.a2(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.c_()
return a},
bd(a){var s
if(a instanceof A.bH)return a.b
if(a==null)return new A.cj(a)
s=a.$cachedTrace
if(s!=null)return s
s=new A.cj(a)
if(typeof a==="object")a.$cachedTrace=s
return s},
i7(a){if(a==null)return J.i(a)
if(typeof a=="object")return A.d5(a)
return J.i(a)},
l_(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.q(0,a[s],a[r])}return b},
jV(a,b,c,d,e,f){t.Y.a(a)
switch(A.a(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.h(new A.e1("Unsupported number of arguments for wrapped closure"))},
eN(a,b){var s=a.$identity
if(!!s)return s
s=A.kH(a,b)
a.$identity=s
return s},
kH(a,b){var s
switch(b){case 0:s=a.$0
break
case 1:s=a.$1
break
case 2:s=a.$2
break
case 3:s=a.$3
break
case 4:s=a.$4
break
default:s=null}if(s!=null)return s.bind(a)
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.jV)},
iE(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.d8().constructor.prototype):Object.create(new A.bi(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.fE(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.iA(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.fE(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
iA(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.h("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.iy)}throw A.h("Error in functionType of tearoff")},
iB(a,b,c,d){var s=A.fC
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
fE(a,b,c,d){if(c)return A.iD(a,b,d)
return A.iB(b.length,d,a,b)},
iC(a,b,c,d){var s=A.fC,r=A.iz
switch(b?-1:a){case 0:throw A.h(new A.d7("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
iD(a,b,c){var s,r
if($.fA==null)$.fA=A.fz("interceptor")
if($.fB==null)$.fB=A.fz("receiver")
s=b.length
r=A.iC(s,c,a,b)
return r},
fo(a){return A.iE(a)},
iy(a,b){return A.co(v.typeUniverse,A.be(a.a),b)},
fC(a){return a.a},
iz(a){return a.b},
fz(a){var s,r,q,p=new A.bi("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.h(A.aF("Field name "+a+" not found.",null))},
i5(a){return v.getIsolateTag(a)},
lA(a,b,c){Object.defineProperty(a,b,{value:c,enumerable:false,writable:true,configurable:true})},
l9(a){var s,r,q,p,o,n=A.ao($.i6.$1(a)),m=$.eO[n]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.eY[n]
if(s!=null)return s
r=v.interceptorsByTag[n]
if(r==null){q=A.hy($.hZ.$2(a,n))
if(q!=null){m=$.eO[q]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.eY[q]
if(s!=null)return s
r=v.interceptorsByTag[q]
n=q}}if(r==null)return null
s=r.prototype
p=n[0]
if(p==="!"){m=A.f_(s)
$.eO[n]=m
Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}if(p==="~"){$.eY[n]=s
return s}if(p==="-"){o=A.f_(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}if(p==="+")return A.i8(a,s)
if(p==="*")throw A.h(A.hg(n))
if(v.leafTags[n]===true){o=A.f_(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}else return A.i8(a,s)},
i8(a,b){var s=Object.getPrototypeOf(a)
Object.defineProperty(s,v.dispatchPropertyName,{value:J.ft(b,s,null,null),enumerable:false,writable:true,configurable:true})
return b},
f_(a){return J.ft(a,!1,null,!!a.$iY)},
lb(a,b,c){var s=b.prototype
if(v.leafTags[a]===true)return A.f_(s)
else return J.ft(s,c,null,null)},
l4(){if(!0===$.fr)return
$.fr=!0
A.l5()},
l5(){var s,r,q,p,o,n,m,l
$.eO=Object.create(null)
$.eY=Object.create(null)
A.l3()
s=v.interceptorsByTag
r=Object.getOwnPropertyNames(s)
if(typeof window!="undefined"){window
q=function(){}
for(p=0;p<r.length;++p){o=r[p]
n=$.i9.$1(o)
if(n!=null){m=A.lb(o,s[o],n)
if(m!=null){Object.defineProperty(n,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
q.prototype=n}}}}for(p=0;p<r.length;++p){o=r[p]
if(/^[A-Za-z_]/.test(o)){l=s[o]
s["!"+o]=l
s["~"+o]=l
s["-"+o]=l
s["+"+o]=l
s["*"+o]=l}}},
l3(){var s,r,q,p,o,n,m=B.v()
m=A.bA(B.w,A.bA(B.x,A.bA(B.o,A.bA(B.o,A.bA(B.y,A.bA(B.z,A.bA(B.A(B.n),m)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){s=dartNativeDispatchHooksTransformer
if(typeof s=="function")s=[s]
if(Array.isArray(s))for(r=0;r<s.length;++r){q=s[r]
if(typeof q=="function")m=q(m)||m}}p=m.getTag
o=m.getUnknownTag
n=m.prototypeForTag
$.i6=new A.eV(p)
$.hZ=new A.eW(o)
$.i9=new A.eX(n)},
bA(a,b){return a(b)||b},
kK(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
fK(a,b,c,d,e,f){var s=b?"m":"",r=c?"":"i",q=d?"u":"",p=e?"s":"",o=function(g,h){try{return new RegExp(g,h)}catch(n){return n}}(a,s+r+q+p+f)
if(o instanceof RegExp)return o
throw A.h(A.fG("Illegal RegExp pattern ("+String(o)+")",a))},
kY(a){if(a.indexOf("$",0)>=0)return a.replace(/\$/g,"$$$$")
return a},
lc(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
ld(a,b,c){var s,r=b.gb4()
r.lastIndex=0
s=a.replace(r,A.kY(c))
return s},
cf:function cf(a,b){this.a=a
this.b=b},
bw:function bw(a,b){this.a=a
this.b=b},
cg:function cg(a,b){this.a=a
this.b=b},
ad:function ad(a,b){this.a=a
this.b=b},
ae:function ae(a,b,c){this.a=a
this.b=b
this.c=c},
ch:function ch(a,b,c){this.a=a
this.b=b
this.c=c},
bE:function bE(){},
aK:function aK(a,b,c){this.a=a
this.b=b
this.$ti=c},
c8:function c8(a,b){this.a=a
this.$ti=b},
c9:function c9(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
bZ:function bZ(){},
dT:function dT(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bV:function bV(){},
cL:function cL(a,b,c){this.a=a
this.b=b
this.c=c},
db:function db(a){this.a=a},
dK:function dK(a){this.a=a},
bH:function bH(a,b){this.a=a
this.b=b},
cj:function cj(a){this.a=a
this.b=null},
aq:function aq(){},
cz:function cz(){},
cA:function cA(){},
d9:function d9(){},
d8:function d8(){},
bi:function bi(a,b){this.a=a
this.b=b},
d7:function d7(a){this.a=a},
aj:function aj(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
dF:function dF(a){this.a=a},
dI:function dI(a,b){var _=this
_.a=a
_.b=b
_.d=_.c=null},
aO:function aO(a,b){this.a=a
this.$ti=b},
bP:function bP(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
bN:function bN(a,b){this.a=a
this.$ti=b},
bO:function bO(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
eV:function eV(a){this.a=a},
eW:function eW(a){this.a=a},
eX:function eX(a){this.a=a},
Z:function Z(){},
an:function an(){},
b7:function b7(){},
cK:function cK(a,b){var _=this
_.a=a
_.b=b
_.e=_.d=_.c=null},
hE(a){return a},
fQ(a,b,c){return c==null?new Uint8Array(a,b):new Uint8Array(a,b,c)},
aB(a,b,c){if(a>>>0!==a||a>=c)throw A.h(A.dv(b,a))},
hD(a,b,c){var s
if(!(a>>>0!==a))s=b>>>0!==b||a>b||b>c
else s=!0
if(s)throw A.h(A.kL(a,b,c))
return b},
at:function at(){},
aa:function aa(){},
bT:function bT(){},
eq:function eq(a){this.a=a},
cP:function cP(){},
N:function N(){},
bR:function bR(){},
bS:function bS(){},
bm:function bm(){},
bn:function bn(){},
cQ:function cQ(){},
bo:function bo(){},
cR:function cR(){},
cS:function cS(){},
cT:function cT(){},
bU:function bU(){},
aR:function aR(){},
cb:function cb(){},
cc:function cc(){},
cd:function cd(){},
ce:function ce(){},
fa(a,b){var s=b.c
return s==null?b.c=A.cm(a,"ah",[b.x]):s},
hd(a){var s=a.w
if(s===6||s===7)return A.hd(a.x)
return s===11||s===12},
j5(a){return a.as},
dw(a){return A.ep(v.typeUniverse,a,!1)},
b9(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.b9(a1,s,a3,a4)
if(r===s)return a2
return A.hr(a1,r,!0)
case 7:s=a2.x
r=A.b9(a1,s,a3,a4)
if(r===s)return a2
return A.hq(a1,r,!0)
case 8:q=a2.y
p=A.bz(a1,q,a3,a4)
if(p===q)return a2
return A.cm(a1,a2.x,p)
case 9:o=a2.x
n=A.b9(a1,o,a3,a4)
m=a2.y
l=A.bz(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.fe(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.bz(a1,j,a3,a4)
if(i===j)return a2
return A.hs(a1,k,i)
case 11:h=a2.x
g=A.b9(a1,h,a3,a4)
f=a2.y
e=A.kw(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.hp(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.bz(a1,d,a3,a4)
o=a2.x
n=A.b9(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.ff(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.h(A.cy("Attempted to substitute unexpected RTI kind "+a0))}},
bz(a,b,c,d){var s,r,q,p,o=b.length,n=A.es(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.b9(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
kx(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.es(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.b9(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
kw(a,b,c,d){var s,r=b.a,q=A.bz(a,r,c,d),p=b.b,o=A.bz(a,p,c,d),n=b.c,m=A.kx(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.dh()
s.a=q
s.b=o
s.c=m
return s},
w(a,b){a[v.arrayRti]=b
return a},
i0(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.l2(s)
return a.$S()}return null},
l6(a,b){var s
if(A.hd(b))if(a instanceof A.aq){s=A.i0(a)
if(s!=null)return s}return A.be(a)},
be(a){if(a instanceof A.o)return A.F(a)
if(Array.isArray(a))return A.E(a)
return A.fi(J.bc(a))},
E(a){var s=a[v.arrayRti],r=t.ce
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
F(a){var s=a.$ti
return s!=null?s:A.fi(a)},
fi(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.jS(a,s)},
jS(a,b){var s=a instanceof A.aq?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.jy(v.typeUniverse,s.name)
b.$ccache=r
return r},
l2(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.ep(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
l1(a){return A.bb(A.F(a))},
fn(a){var s
if(a instanceof A.Z)return A.kZ(a.$r,a.aa())
s=a instanceof A.aq?A.i0(a):null
if(s!=null)return s
if(t.bW.b(a))return J.it(a).a
if(Array.isArray(a))return A.E(a)
return A.be(a)},
bb(a){var s=a.r
return s==null?a.r=new A.eo(a):s},
kZ(a,b){var s,r,q=b,p=q.length
if(p===0)return t.cD
if(0>=p)return A.c(q,0)
s=A.co(v.typeUniverse,A.fn(q[0]),"@<0>")
for(r=1;r<p;++r){if(!(r<q.length))return A.c(q,r)
s=A.ht(v.typeUniverse,s,A.fn(q[r]))}return A.co(v.typeUniverse,s,a)},
a8(a){return A.bb(A.ep(v.typeUniverse,a,!1))},
jR(a){var s=this
s.b=A.kt(s)
return s.b(a)},
kt(a){var s,r,q,p,o
if(a===t.K)return A.k0
if(A.bf(a))return A.k4
s=a.w
if(s===6)return A.jO
if(s===1)return A.hJ
if(s===7)return A.jW
r=A.ks(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.bf)){a.f="$i"+q
if(q==="n")return A.jZ
if(a===t.m)return A.jY
return A.k3}}else if(s===10){p=A.kK(a.x,a.y)
o=p==null?A.hJ:p
return o==null?A.bx(o):o}return A.jM},
ks(a){if(a.w===8){if(a===t.S)return A.eD
if(a===t.i||a===t.o)return A.k_
if(a===t.N)return A.k2
if(a===t.y)return A.fj}return null},
jQ(a){var s=this,r=A.jL
if(A.bf(s))r=A.jD
else if(s===t.K)r=A.bx
else if(A.bB(s)){r=A.jN
if(s===t.a3)r=A.dq
else if(s===t.aD)r=A.hy
else if(s===t.cG)r=A.jA
else if(s===t.ae)r=A.hx
else if(s===t.I)r=A.jB
else if(s===t.aQ)r=A.hw}else if(s===t.S)r=A.a
else if(s===t.N)r=A.ao
else if(s===t.y)r=A.dp
else if(s===t.o)r=A.jC
else if(s===t.i)r=A.eu
else if(s===t.m)r=A.ev
s.a=r
return s.a(a)},
jM(a){var s=this
if(a==null)return A.bB(s)
return A.l8(v.typeUniverse,A.l6(a,s),s)},
jO(a){if(a==null)return!0
return this.x.b(a)},
k3(a){var s,r=this
if(a==null)return A.bB(r)
s=r.f
if(a instanceof A.o)return!!a[s]
return!!J.bc(a)[s]},
jZ(a){var s,r=this
if(a==null)return A.bB(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.o)return!!a[s]
return!!J.bc(a)[s]},
jY(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.o)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
hI(a){if(typeof a=="object"){if(a instanceof A.o)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
jL(a){var s=this
if(a==null){if(A.bB(s))return a}else if(s.b(a))return a
throw A.K(A.hF(a,s),new Error())},
jN(a){var s=this
if(a==null||s.b(a))return a
throw A.K(A.hF(a,s),new Error())},
hF(a,b){return new A.ck("TypeError: "+A.hj(a,A.a_(b,null)))},
hj(a,b){return A.cF(a)+": type '"+A.a_(A.fn(a),null)+"' is not a subtype of type '"+b+"'"},
a3(a,b){return new A.ck("TypeError: "+A.hj(a,b))},
jW(a){var s=this
return s.x.b(a)||A.fa(v.typeUniverse,s).b(a)},
k0(a){return a!=null},
bx(a){if(a!=null)return a
throw A.K(A.a3(a,"Object"),new Error())},
k4(a){return!0},
jD(a){return a},
hJ(a){return!1},
fj(a){return!0===a||!1===a},
dp(a){if(!0===a)return!0
if(!1===a)return!1
throw A.K(A.a3(a,"bool"),new Error())},
jA(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.K(A.a3(a,"bool?"),new Error())},
eu(a){if(typeof a=="number")return a
throw A.K(A.a3(a,"double"),new Error())},
jB(a){if(typeof a=="number")return a
if(a==null)return a
throw A.K(A.a3(a,"double?"),new Error())},
eD(a){return typeof a=="number"&&Math.floor(a)===a},
a(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.K(A.a3(a,"int"),new Error())},
dq(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.K(A.a3(a,"int?"),new Error())},
k_(a){return typeof a=="number"},
jC(a){if(typeof a=="number")return a
throw A.K(A.a3(a,"num"),new Error())},
hx(a){if(typeof a=="number")return a
if(a==null)return a
throw A.K(A.a3(a,"num?"),new Error())},
k2(a){return typeof a=="string"},
ao(a){if(typeof a=="string")return a
throw A.K(A.a3(a,"String"),new Error())},
hy(a){if(typeof a=="string")return a
if(a==null)return a
throw A.K(A.a3(a,"String?"),new Error())},
ev(a){if(A.hI(a))return a
throw A.K(A.a3(a,"JSObject"),new Error())},
hw(a){if(a==null)return a
if(A.hI(a))return a
throw A.K(A.a3(a,"JSObject?"),new Error())},
hV(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.a_(a[q],b)
return s},
km(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.hV(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.a_(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
hG(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
if(a5!=null){s=a5.length
if(a4==null)a4=A.w([],t.s)
else a2=a4.length
r=a4.length
for(q=s;q>0;--q)B.d.u(a4,"T"+(r+q))
for(p=t.X,o="<",n="",q=0;q<s;++q,n=a1){m=a4.length
l=m-1-q
if(!(l>=0))return A.c(a4,l)
o=o+n+a4[l]
k=a5[q]
j=k.w
if(!(j===2||j===3||j===4||j===5||k===p))o+=" extends "+A.a_(k,a4)}o+=">"}else o=""
p=a3.x
i=a3.y
h=i.a
g=h.length
f=i.b
e=f.length
d=i.c
c=d.length
b=A.a_(p,a4)
for(a="",a0="",q=0;q<g;++q,a0=a1)a+=a0+A.a_(h[q],a4)
if(e>0){a+=a0+"["
for(a0="",q=0;q<e;++q,a0=a1)a+=a0+A.a_(f[q],a4)
a+="]"}if(c>0){a+=a0+"{"
for(a0="",q=0;q<c;q+=3,a0=a1){a+=a0
if(d[q+1])a+="required "
a+=A.a_(d[q+2],a4)+" "+d[q]}a+="}"}if(a2!=null){a4.toString
a4.length=a2}return o+"("+a+") => "+b},
a_(a,b){var s,r,q,p,o,n,m,l=a.w
if(l===5)return"erased"
if(l===2)return"dynamic"
if(l===3)return"void"
if(l===1)return"Never"
if(l===4)return"any"
if(l===6){s=a.x
r=A.a_(s,b)
q=s.w
return(q===11||q===12?"("+r+")":r)+"?"}if(l===7)return"FutureOr<"+A.a_(a.x,b)+">"
if(l===8){p=A.ky(a.x)
o=a.y
return o.length>0?p+("<"+A.hV(o,b)+">"):p}if(l===10)return A.km(a,b)
if(l===11)return A.hG(a,b,null)
if(l===12)return A.hG(a.x,b,a.y)
if(l===13){n=a.x
m=b.length
n=m-1-n
if(!(n>=0&&n<m))return A.c(b,n)
return b[n]}return"?"},
ky(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
jz(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
jy(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.ep(a,b,!1)
else if(typeof m=="number"){s=m
r=A.cn(a,5,"#")
q=A.es(s)
for(p=0;p<s;++p)q[p]=r
o=A.cm(a,b,q)
n[b]=o
return o}else return m},
jx(a,b){return A.hu(a.tR,b)},
jw(a,b){return A.hu(a.eT,b)},
ep(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.hn(A.hl(a,null,b,!1))
r.set(b,s)
return s},
co(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.hn(A.hl(a,b,c,!0))
q.set(c,r)
return r},
ht(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.fe(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
aA(a,b){b.a=A.jQ
b.b=A.jR
return b},
cn(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.a6(null,null)
s.w=b
s.as=c
r=A.aA(a,s)
a.eC.set(c,r)
return r},
hr(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.ju(a,b,r,c)
a.eC.set(r,s)
return s},
ju(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.bf(b))if(!(b===t.P||b===t.T))if(s!==6)r=s===7&&A.bB(b.x)
if(r)return b
else if(s===1)return t.P}q=new A.a6(null,null)
q.w=6
q.x=b
q.as=c
return A.aA(a,q)},
hq(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.js(a,b,r,c)
a.eC.set(r,s)
return s},
js(a,b,c,d){var s,r
if(d){s=b.w
if(A.bf(b)||b===t.K)return b
else if(s===1)return A.cm(a,"ah",[b])
else if(b===t.P||b===t.T)return t.bc}r=new A.a6(null,null)
r.w=7
r.x=b
r.as=c
return A.aA(a,r)},
jv(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.a6(null,null)
s.w=13
s.x=b
s.as=q
r=A.aA(a,s)
a.eC.set(q,r)
return r},
cl(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
jr(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
cm(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.cl(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.a6(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.aA(a,r)
a.eC.set(p,q)
return q},
fe(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.cl(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.a6(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.aA(a,o)
a.eC.set(q,n)
return n},
hs(a,b,c){var s,r,q="+"+(b+"("+A.cl(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.a6(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.aA(a,s)
a.eC.set(q,r)
return r},
hp(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.cl(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.cl(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.jr(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.a6(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.aA(a,p)
a.eC.set(r,o)
return o},
ff(a,b,c,d){var s,r=b.as+("<"+A.cl(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.jt(a,b,c,r,d)
a.eC.set(r,s)
return s},
jt(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.es(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.b9(a,b,r,0)
m=A.bz(a,c,r,0)
return A.ff(a,n,m,c!==m)}}l=new A.a6(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.aA(a,l)},
hl(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
hn(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.jl(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.hm(a,r,l,k,!1)
else if(q===46)r=A.hm(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.b6(a.u,a.e,k.pop()))
break
case 94:k.push(A.jv(a.u,k.pop()))
break
case 35:k.push(A.cn(a.u,5,"#"))
break
case 64:k.push(A.cn(a.u,2,"@"))
break
case 126:k.push(A.cn(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.jn(a,k)
break
case 38:A.jm(a,k)
break
case 63:p=a.u
k.push(A.hr(p,A.b6(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.hq(p,A.b6(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.jk(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.ho(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.jp(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-2)
break
case 43:n=l.indexOf("(",r)
k.push(l.substring(r,n))
k.push(-4)
k.push(a.p)
a.p=k.length
r=n+1
break
default:throw"Bad character "+q}}}m=k.pop()
return A.b6(a.u,a.e,m)},
jl(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
hm(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.jz(s,o.x)[p]
if(n==null)A.a1('No "'+p+'" in "'+A.j5(o)+'"')
d.push(A.co(s,o,n))}else d.push(p)
return m},
jn(a,b){var s,r=a.u,q=A.hk(a,b),p=b.pop()
if(typeof p=="string")b.push(A.cm(r,p,q))
else{s=A.b6(r,a.e,p)
switch(s.w){case 11:b.push(A.ff(r,s,q,a.n))
break
default:b.push(A.fe(r,s,q))
break}}},
jk(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.hk(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.b6(p,a.e,o)
q=new A.dh()
q.a=s
q.b=n
q.c=m
b.push(A.hp(p,r,q))
return
case-4:b.push(A.hs(p,b.pop(),s))
return
default:throw A.h(A.cy("Unexpected state under `()`: "+A.e(o)))}},
jm(a,b){var s=b.pop()
if(0===s){b.push(A.cn(a.u,1,"0&"))
return}if(1===s){b.push(A.cn(a.u,4,"1&"))
return}throw A.h(A.cy("Unexpected extended operation "+A.e(s)))},
hk(a,b){var s=b.splice(a.p)
A.ho(a.u,a.e,s)
a.p=b.pop()
return s},
b6(a,b,c){if(typeof c=="string")return A.cm(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.jo(a,b,c)}else return c},
ho(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.b6(a,b,c[s])},
jp(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.b6(a,b,c[s])},
jo(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.h(A.cy("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.h(A.cy("Bad index "+c+" for "+b.i(0)))},
l8(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.I(a,b,null,c,null)
r.set(c,s)}return s},
I(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.bf(d))return!0
s=b.w
if(s===4)return!0
if(A.bf(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.I(a,c[b.x],c,d,e))return!0
q=d.w
p=t.P
if(b===p||b===t.T){if(q===7)return A.I(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.K){if(s===7)return A.I(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.I(a,b.x,c,d,e))return!1
return A.I(a,A.fa(a,b),c,d,e)}if(s===6)return A.I(a,p,c,d,e)&&A.I(a,b.x,c,d,e)
if(q===7){if(A.I(a,b,c,d.x,e))return!0
return A.I(a,b,c,A.fa(a,d),e)}if(q===6)return A.I(a,b,c,p,e)||A.I(a,b,c,d.x,e)
if(r)return!1
p=s!==11
if((!p||s===12)&&d===t.Y)return!0
o=s===10
if(o&&d===t.cY)return!0
if(q===12){if(b===t.g)return!0
if(s!==12)return!1
n=b.y
m=d.y
l=n.length
if(l!==m.length)return!1
c=c==null?n:n.concat(c)
e=e==null?m:m.concat(e)
for(k=0;k<l;++k){j=n[k]
i=m[k]
if(!A.I(a,j,c,i,e)||!A.I(a,i,e,j,c))return!1}return A.hH(a,b.x,c,d.x,e)}if(q===11){if(b===t.g)return!0
if(p)return!1
return A.hH(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.jX(a,b,c,d,e)}if(o&&q===10)return A.k1(a,b,c,d,e)
return!1},
hH(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.I(a3,a4.x,a5,a6.x,a7))return!1
s=a4.y
r=a6.y
q=s.a
p=r.a
o=q.length
n=p.length
if(o>n)return!1
m=n-o
l=s.b
k=r.b
j=l.length
i=k.length
if(o+j<n+i)return!1
for(h=0;h<o;++h){g=q[h]
if(!A.I(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.I(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.I(a3,k[h],a7,g,a5))return!1}f=s.c
e=r.c
d=f.length
c=e.length
for(b=0,a=0;a<c;a+=3){a0=e[a]
for(;;){if(b>=d)return!1
a1=f[b]
b+=3
if(a0<a1)return!1
a2=f[b-2]
if(a1<a0){if(a2)return!1
continue}g=e[a+1]
if(a2&&!g)return!1
g=f[b-1]
if(!A.I(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
jX(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.co(a,b,r[o])
return A.hv(a,p,null,c,d.y,e)}return A.hv(a,b.y,null,c,d.y,e)},
hv(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.I(a,b[s],d,e[s],f))return!1
return!0},
k1(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.I(a,r[s],c,q[s],e))return!1
return!0},
bB(a){var s=a.w,r=!0
if(!(a===t.P||a===t.T))if(!A.bf(a))if(s!==6)r=s===7&&A.bB(a.x)
return r},
bf(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.X},
hu(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
es(a){return a>0?new Array(a):v.typeUniverse.sEA},
a6:function a6(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
dh:function dh(){this.c=this.b=this.a=null},
eo:function eo(a){this.a=a},
dg:function dg(){},
ck:function ck(a){this.a=a},
jd(){var s,r,q
if(self.scheduleImmediate!=null)return A.kB()
if(self.MutationObserver!=null&&self.document!=null){s={}
r=self.document.createElement("div")
q=self.document.createElement("span")
s.a=null
new self.MutationObserver(A.eN(new A.dY(s),1)).observe(r,{childList:true})
return new A.dX(s,r,q)}else if(self.setImmediate!=null)return A.kC()
return A.kD()},
je(a){self.scheduleImmediate(A.eN(new A.dZ(t.M.a(a)),0))},
jf(a){self.setImmediate(A.eN(new A.e_(t.M.a(a)),0))},
jg(a){A.fc(B.j,t.M.a(a))},
fc(a,b){var s=B.c.O(a.a,1000)
return A.jq(s<0?0:s,b)},
jq(a,b){var s=new A.em()
s.aW(a,b)
return s},
hK(a){return new A.dd(new A.D($.z,a.h("D<0>")),a.h("dd<0>"))},
hC(a,b){a.$2(0,null)
b.b=!0
return b.a},
hz(a,b){A.jE(a,b)},
hB(a,b){b.ah(a)},
hA(a,b){b.aI(A.af(a),A.bd(a))},
jE(a,b){var s,r,q=new A.ew(b),p=new A.ex(b)
if(a instanceof A.D)a.aB(q,p,t.z)
else{s=t.z
if(a instanceof A.D)a.an(q,p,s)
else{r=new A.D($.z,t._)
r.a=8
r.c=a
r.aB(q,p,s)}}},
hY(a){var s=function(b,c){return function(d,e){while(true){try{b(d,e)
break}catch(r){e=r
d=c}}}}(a,1)
return $.z.aL(new A.eK(s),t.H,t.S,t.z)},
dz(a){var s
if(t.C.b(a)){s=a.gT()
if(s!=null)return s}return B.D},
jT(a,b){if($.z===B.f)return null
return null},
jU(a,b){if($.z!==B.f)A.jT(a,b)
if(t.C.b(a))A.j2(a,b)
return new A.W(a,b)},
e5(a,b,c){var s,r,q,p,o={},n=o.a=a
for(s=t._;r=n.a,(r&4)!==0;n=a){a=s.a(n.c)
o.a=a}if(n===b){s=A.j6()
b.a5(new A.W(new A.a2(!0,n,null,"Cannot complete a future with itself"),s))
return}q=b.a&1
s=n.a=r|q
if((s&24)===0){p=t.F.a(b.c)
b.a=b.a&1|4
b.c=n
n.aA(p)
return}if(!c)if(b.c==null)n=(s&16)===0||q!==0
else n=!1
else n=!0
if(n){p=b.S()
b.U(o.a)
A.b4(b,p)
return}b.a^=2
A.dt(null,null,b.b,t.M.a(new A.e6(o,b)))},
b4(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d={},c=d.a=a
for(s=t.n,r=t.F;;){q={}
p=c.a
o=(p&16)===0
n=!o
if(b==null){if(n&&(p&1)===0){m=s.a(c.c)
A.fm(m.a,m.b)}return}q.a=b
l=b.a
for(c=b;l!=null;c=l,l=k){c.a=null
A.b4(d.a,c)
q.a=l
k=l.a}p=d.a
j=p.c
q.b=n
q.c=j
if(o){i=c.c
i=(i&1)!==0||(i&15)===8}else i=!0
if(i){h=c.b.b
if(n){p=p.b===h
p=!(p||p)}else p=!1
if(p){s.a(j)
A.fm(j.a,j.b)
return}g=$.z
if(g!==h)$.z=h
else g=null
c=c.c
if((c&15)===8)new A.ea(q,d,n).$0()
else if(o){if((c&1)!==0)new A.e9(q,j).$0()}else if((c&2)!==0)new A.e8(d,q).$0()
if(g!=null)$.z=g
c=q.c
if(c instanceof A.D){p=q.a.$ti
p=p.h("ah<2>").b(c)||!p.y[1].b(c)}else p=!1
if(p){f=q.a.b
if((c.a&24)!==0){e=r.a(f.c)
f.c=null
b=f.X(e)
f.a=c.a&30|f.a&1
f.c=c.c
d.a=c
continue}else A.e5(c,f,!0)
return}}f=q.a.b
e=r.a(f.c)
f.c=null
b=f.X(e)
c=q.b
p=q.c
if(!c){f.$ti.c.a(p)
f.a=8
f.c=p}else{s.a(p)
f.a=f.a&1|16
f.c=p}d.a=f
c=f}},
kn(a,b){var s
if(t.U.b(a))return b.aL(a,t.z,t.K,t.l)
s=t.v
if(s.b(a))return s.a(a)
throw A.h(A.dy(a,"onError",u.c))},
k6(){var s,r
for(s=$.by;s!=null;s=$.by){$.cs=null
r=s.b
$.by=r
if(r==null)$.cr=null
s.a.$0()}},
ku(){$.fk=!0
try{A.k6()}finally{$.cs=null
$.fk=!1
if($.by!=null)$.fu().$1(A.i_())}},
hW(a){var s=new A.de(a),r=$.cr
if(r==null){$.by=$.cr=s
if(!$.fk)$.fu().$1(A.i_())}else $.cr=r.b=s},
kr(a){var s,r,q,p=$.by
if(p==null){A.hW(a)
$.cs=$.cr
return}s=new A.de(a)
r=$.cs
if(r==null){s.b=p
$.by=$.cs=s}else{q=r.b
s.b=q
$.cs=r.b=s
if(q==null)$.cr=s}},
lm(a,b){A.eM(a,"stream",t.K)
return new A.dm(b.h("dm<0>"))},
j9(a,b){var s=$.z
if(s===B.f)return A.fc(a,t.M.a(b))
return A.fc(a,t.M.a(s.aF(b)))},
fm(a,b){A.kr(new A.eJ(a,b))},
hU(a,b,c,d,e){var s,r=$.z
if(r===c)return d.$0()
$.z=c
s=r
try{r=d.$0()
return r}finally{$.z=s}},
kq(a,b,c,d,e,f,g){var s,r=$.z
if(r===c)return d.$1(e)
$.z=c
s=r
try{r=d.$1(e)
return r}finally{$.z=s}},
kp(a,b,c,d,e,f,g,h,i){var s,r=$.z
if(r===c)return d.$2(e,f)
$.z=c
s=r
try{r=d.$2(e,f)
return r}finally{$.z=s}},
dt(a,b,c,d){t.M.a(d)
if(B.f!==c){d=c.aF(d)
d=d}A.hW(d)},
dY:function dY(a){this.a=a},
dX:function dX(a,b,c){this.a=a
this.b=b
this.c=c},
dZ:function dZ(a){this.a=a},
e_:function e_(a){this.a=a},
em:function em(){this.b=null},
en:function en(a,b){this.a=a
this.b=b},
dd:function dd(a,b){this.a=a
this.b=!1
this.$ti=b},
ew:function ew(a){this.a=a},
ex:function ex(a){this.a=a},
eK:function eK(a){this.a=a},
W:function W(a,b){this.a=a
this.b=b},
df:function df(){},
c5:function c5(a,b){this.a=a
this.$ti=b},
b3:function b3(a,b,c,d,e){var _=this
_.a=null
_.b=a
_.c=b
_.d=c
_.e=d
_.$ti=e},
D:function D(a,b){var _=this
_.a=0
_.b=a
_.c=null
_.$ti=b},
e2:function e2(a,b){this.a=a
this.b=b},
e7:function e7(a,b){this.a=a
this.b=b},
e6:function e6(a,b){this.a=a
this.b=b},
e4:function e4(a,b){this.a=a
this.b=b},
e3:function e3(a,b){this.a=a
this.b=b},
ea:function ea(a,b,c){this.a=a
this.b=b
this.c=c},
eb:function eb(a,b){this.a=a
this.b=b},
ec:function ec(a){this.a=a},
e9:function e9(a,b){this.a=a
this.b=b},
e8:function e8(a,b){this.a=a
this.b=b},
ed:function ed(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ee:function ee(a,b,c){this.a=a
this.b=b
this.c=c},
ef:function ef(a,b){this.a=a
this.b=b},
de:function de(a){this.a=a
this.b=null},
dm:function dm(a){this.$ti=a},
cp:function cp(){},
dl:function dl(){},
el:function el(a,b){this.a=a
this.b=b},
eJ:function eJ(a,b){this.a=a
this.b=b},
iU(a,b){return new A.aj(a.h("@<0>").t(b).h("aj<1,2>"))},
q(a,b,c){return b.h("@<0>").t(c).h("fM<1,2>").a(A.l_(a,new A.aj(b.h("@<0>").t(c).h("aj<1,2>"))))},
fN(a,b){return new A.aj(a.h("@<0>").t(b).h("aj<1,2>"))},
fO(a){return new A.ca(a.h("ca<0>"))},
fd(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
jj(a,b,c){var s=new A.b5(a,b,c.h("b5<0>"))
s.c=a.e
return s},
ak(a,b,c){var s=A.iU(b,c)
s.bb(0,a)
return s},
f6(a){var s,r
if(A.fs(a))return"{...}"
s=new A.b1("")
try{r={}
B.d.u($.a0,a)
s.a+="{"
r.a=!0
a.J(0,new A.dJ(r,s))
s.a+="}"}finally{if(0>=$.a0.length)return A.c($.a0,-1)
$.a0.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
ca:function ca(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
dk:function dk(a){this.a=a
this.b=null},
b5:function b5(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
p:function p(){},
L:function L(){},
dJ:function dJ(a,b){this.a=a
this.b=b},
bu:function bu(){},
ci:function ci(){},
k7(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.af(r)
q=A.fG(String(s),null)
throw A.h(q)}q=A.ey(p)
return q},
ey(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.di(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.ey(a[s])
return a},
fL(a,b,c){return new A.bM(a,b)},
jJ(a){return a.bF()},
jh(a,b){return new A.eh(a,[],A.kI())},
ji(a,b,c){var s,r=new A.b1(""),q=A.jh(r,b)
q.Z(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
di:function di(a,b){this.a=a
this.b=b
this.c=null},
dj:function dj(a){this.a=a},
cC:function cC(){},
cE:function cE(){},
bM:function bM(a,b){this.a=a
this.b=b},
cN:function cN(a,b){this.a=a
this.b=b},
cM:function cM(){},
dH:function dH(a){this.b=a},
dG:function dG(a){this.a=a},
ei:function ei(){},
ej:function ej(a,b){this.a=a
this.b=b},
eh:function eh(a,b,c){this.c=a
this.a=b
this.b=c},
dV:function dV(){},
er:function er(a){this.b=0
this.c=a},
iH(a,b){a=A.K(a,new Error())
if(a==null)a=A.bx(a)
a.stack=b.i(0)
throw a},
f5(a,b,c,d){var s,r=J.iP(a,d)
if(a!==0&&b!=null)for(s=0;s<a;++s)r[s]=b
return r},
iV(a,b,c){var s,r,q=A.w([],c.h("v<0>"))
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.cv)(a),++r)B.d.u(q,c.a(a[r]))
q.$flags=1
return q},
U(a,b){var s,r
if(Array.isArray(a))return A.w(a.slice(0),b.h("v<0>"))
s=A.w([],b.h("v<0>"))
for(r=J.cw(a);r.v();)B.d.u(s,r.gA())
return s},
fb(a){var s,r,q
A.f9(0,"start")
if(Array.isArray(a)){s=a
r=s.length
return A.ha(r<r?s.slice(0,r):s)}if(t.Z.b(a))return A.j8(a,0,null)
q=A.U(a,t.S)
return A.ha(q)},
j8(a,b,c){var s=a.length
if(b>=s)return""
return A.j1(a,b,s)},
j4(a){return new A.cK(a,A.fK(a,!1,!0,!1,!1,""))},
he(a,b,c){var s=J.cw(b)
if(!s.v())return a
if(c.length===0){do a+=A.e(s.gA())
while(s.v())}else{a+=A.e(s.gA())
while(s.v())a=a+c+A.e(s.gA())}return a},
j6(){return A.bd(new Error())},
iF(a,b,c,d,e,f){var s=A.j3(a,b,c,d,e,f,0,0,!0)
return new A.bF(s==null?new A.dB(a,b,c,d,e,f,0,0).$0():s,0,!0)},
fF(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
iG(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
dC(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
ag(a){if(a>=10)return""+a
return"0"+a},
cF(a){if(typeof a=="number"||A.fj(a)||a==null)return J.ap(a)
if(typeof a=="string")return JSON.stringify(a)
return A.h9(a)},
iI(a,b){A.eM(a,"error",t.K)
A.eM(b,"stackTrace",t.l)
A.iH(a,b)},
cy(a){return new A.cx(a)},
aF(a,b){return new A.a2(!1,null,b,a)},
dy(a,b,c){return new A.a2(!0,a,b,c)},
hb(a,b){return new A.ax(null,null,!0,a,b,"Value not in range")},
V(a,b,c,d,e){return new A.ax(b,c,!0,a,d,"Invalid value")},
hc(a,b,c){if(0>a||a>c)throw A.h(A.V(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.h(A.V(b,a,c,"end",null))
return b}return c},
f9(a,b){if(a<0)throw A.h(A.V(a,0,null,b,null))
return a},
f1(a,b,c,d){return new A.cG(b,!0,a,d,"Index out of range")},
dc(a){return new A.c2(a)},
hg(a){return new A.da(a)},
dS(a){return new A.c0(a)},
aJ(a){return new A.cD(a)},
fG(a,b){return new A.dD(a,b)},
iO(a,b,c){var s,r
if(A.fs(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.w([],t.s)
B.d.u($.a0,a)
try{A.k5(a,s)}finally{if(0>=$.a0.length)return A.c($.a0,-1)
$.a0.pop()}r=A.he(b,t.r.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
f2(a,b,c){var s,r
if(A.fs(a))return b+"..."+c
s=new A.b1(b)
B.d.u($.a0,a)
try{r=s
r.a=A.he(r.a,a,", ")}finally{if(0>=$.a0.length)return A.c($.a0,-1)
$.a0.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
k5(a,b){var s,r,q,p,o,n,m,l=a.gC(a),k=0,j=0
for(;;){if(!(k<80||j<3))break
if(!l.v())return
s=A.e(l.gA())
B.d.u(b,s)
k+=s.length+2;++j}if(!l.v()){if(j<=5)return
if(0>=b.length)return A.c(b,-1)
r=b.pop()
if(0>=b.length)return A.c(b,-1)
q=b.pop()}else{p=l.gA();++j
if(!l.v()){if(j<=4){B.d.u(b,A.e(p))
return}r=A.e(p)
if(0>=b.length)return A.c(b,-1)
q=b.pop()
k+=r.length+2}else{o=l.gA();++j
for(;l.v();p=o,o=n){n=l.gA();++j
if(j>100){for(;;){if(!(k>75&&j>3))break
if(0>=b.length)return A.c(b,-1)
k-=b.pop().length+2;--j}B.d.u(b,"...")
return}}q=A.e(p)
r=A.e(o)
k+=r.length+q.length+4}}if(j>b.length+2){k+=5
m="..."}else m=null
for(;;){if(!(k>80&&b.length>3))break
if(0>=b.length)return A.c(b,-1)
k-=b.pop().length+2
if(m==null){k+=5
m="..."}}if(m!=null)B.d.u(b,m)
B.d.u(b,q)
B.d.u(b,r)},
fP(a,b,c,d,e){return new A.aI(a,b.h("@<0>").t(c).t(d).t(e).h("aI<1,2,3,4>"))},
y(a,b,c,d,e,f,g,h,i,j,k){var s
if(B.a===c){s=J.i(a)
b=J.i(b)
return A.ab(A.k(A.k($.a9(),s),b))}if(B.a===d){s=J.i(a)
b=J.i(b)
c=J.i(c)
return A.ab(A.k(A.k(A.k($.a9(),s),b),c))}if(B.a===e){s=J.i(a)
b=J.i(b)
c=J.i(c)
d=J.i(d)
return A.ab(A.k(A.k(A.k(A.k($.a9(),s),b),c),d))}if(B.a===f){s=J.i(a)
b=J.i(b)
c=J.i(c)
d=J.i(d)
e=J.i(e)
return A.ab(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e))}if(B.a===g){s=J.i(a)
b=J.i(b)
c=J.i(c)
d=J.i(d)
e=J.i(e)
f=J.i(f)
return A.ab(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f))}if(B.a===h){s=J.i(a)
b=J.i(b)
c=J.i(c)
d=J.i(d)
e=J.i(e)
f=J.i(f)
g=J.i(g)
return A.ab(A.k(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f),g))}if(B.a===i){s=J.i(a)
b=J.i(b)
c=J.i(c)
d=J.i(d)
e=J.i(e)
f=J.i(f)
g=J.i(g)
h=J.i(h)
return A.ab(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f),g),h))}if(B.a===j){s=J.i(a)
b=J.i(b)
c=J.i(c)
d=J.i(d)
e=J.i(e)
f=J.i(f)
g=J.i(g)
h=J.i(h)
i=J.i(i)
return A.ab(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f),g),h),i))}if(B.a===k){s=J.i(a)
b=J.i(b)
c=J.i(c)
d=J.i(d)
e=J.i(e)
f=J.i(f)
g=J.i(g)
h=J.i(h)
i=J.i(i)
j=J.i(j)
return A.ab(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f),g),h),i),j))}s=J.i(a)
b=J.i(b)
c=J.i(c)
d=J.i(d)
e=J.i(e)
f=J.i(f)
g=J.i(g)
h=J.i(h)
i=J.i(i)
j=J.i(j)
k=J.i(k)
k=A.ab(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f),g),h),i),j),k))
return k},
bp(a){var s,r
t.J.a(a)
s=$.a9()
for(r=J.cw(a);r.v();)s=A.k(s,J.i(r.gA()))
return A.ab(s)},
dB:function dB(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
bF:function bF(a,b,c){this.a=a
this.b=b
this.c=c},
aL:function aL(a){this.a=a},
e0:function e0(){},
x:function x(){},
cx:function cx(a){this.a=a},
al:function al(){},
a2:function a2(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ax:function ax(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
cG:function cG(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
c2:function c2(a){this.a=a},
da:function da(a){this.a=a},
c0:function c0(a){this.a=a},
cD:function cD(a){this.a=a},
cU:function cU(){},
c_:function c_(){},
e1:function e1(a){this.a=a},
dD:function dD(a,b){this.a=a
this.b=b},
f:function f(){},
as:function as(a,b,c){this.a=a
this.b=b
this.$ti=c},
G:function G(){},
o:function o(){},
dn:function dn(){},
b1:function b1(a){this.a=a},
kU(a,b){var s,r,q,p=A.a(a._malloc(4)),o=null
try{s=A.a(a._FPDF_GetFileVersion(b,p))
if(!J.d(s,0)){r=t.A.a(a.HEAP32)
q=p
if(typeof q!=="number")return q.bE()
q=B.b.l(q,2)
if(!(q<r.length))return A.c(r,q)
o=r[q]}}finally{a._free(p)}return new A.dM(o,A.hQ(a,b,0),A.hQ(a,b,1))},
i2(a,b,c){var s,r,q,p=A.a(a._FPDF_GetPageCount(b))
if(c<0||c>=p)throw A.h(A.V(c,0,p-1,"pageIndex",null))
s=A.a(a._FPDF_LoadPage(b,c))
if(J.d(s,0))throw A.h(A.f8(B.l))
try{r=A.eu(a._FPDF_GetPageWidthF(s))
q=A.eu(a._FPDF_GetPageHeightF(s))
return new A.d0(r,q)}finally{a._FPDF_ClosePage(s)}},
eT(a,b,c){var s,r,q,p=A.a(a._FPDF_GetPageCount(b)),o=c!=null
if(o)s=c<0||c>=p
else s=!1
if(s)throw A.h(A.V(c,0,p-1,"pageIndex",null))
if(o)o=A.w([c],t.t)
else{r=J.fH(p,t.S)
for(q=0;q<p;++q)r[q]=q
o=r}return o},
i3(a,b,c,d,e,f,g,h){var s,r,q,p,o,n,m,l,k,j=A.a(a._FPDF_GetPageCount(b))
if(c<0||c>=j)throw A.h(A.V(c,0,j-1,"pageIndex",null))
s=A.a(a._FPDF_LoadPage(b,c))
if(J.d(s,0))throw A.h(A.bY("FPDF_LoadPage returned null for page "+c+"."))
try{r=A.a(a._FPDFBitmap_Create(d,e,1))
if(J.d(r,0)){k=A.bY("FPDFBitmap_Create returned null for "+d+"x"+e+" (possible out-of-memory).")
throw A.h(k)}try{q=0
if(h){k=q
if(typeof k!=="number")return k.aR()
q=(k|1)>>>0}if(g){k=q
if(typeof k!=="number")return k.aR()
q=(k|2)>>>0}k=t.H
A.du(a,"_FPDFBitmap_FillRect",[r,0,0,d,e,f],k)
A.du(a,"_FPDF_RenderPageBitmap",[r,s,0,0,d,e,0,q],k)
p=A.a(a._FPDFBitmap_GetBuffer(r))
o=A.a(a._FPDFBitmap_GetStride(r))
k=o
if(typeof k!=="number")return k.E()
n=k*e
m=J.fv(B.i.gae(t.Z.a(a.HEAPU8)),p,n)
l=A.ia(m,d,e,o)
return new A.ch(e,d,l)}finally{a._FPDFBitmap_Destroy(r)}}finally{a._FPDF_ClosePage(s)}},
kV(a,b,c,d,e){var s,r,q,p,o,n,m,l,k
if(e<=0)throw A.h(A.dy(e,"maxDimension","maxDimension must be greater than 0"))
p=A.a(a._FPDF_GetPageCount(b))
if(c<0||c>=p)throw A.h(A.V(c,0,p-1,"pageIndex",null))
s=A.a(a._FPDF_LoadPage(b,c))
if(J.d(s,0))throw A.h(A.bY("FPDF_LoadPage returned null for page "+c+"."))
try{r=A.a(a._FPDFPage_GetThumbnailAsBitmap(s))
if(!J.d(r,0))try{q=A.kl(a,r,c)
if(q!=null)return q}finally{a._FPDFBitmap_Destroy(r)}}finally{a._FPDF_ClosePage(s)}if(!d)return null
o=A.i2(a,b,c)
n=o.a
m=o.b
l=n>=m?e/n:e/m
k=A.i3(a,b,c,B.c.aH(B.b.aM(n*l),1,e),B.c.aH(B.b.aM(m*l),1,e),4294967295,!1,!0)
return new A.bX(k.c,k.b,k.a,B.an)},
kl(a,b,c){var s=A.a(a._FPDFBitmap_GetWidth(b)),r=A.a(a._FPDFBitmap_GetHeight(b)),q=A.a(a._FPDFBitmap_GetStride(b)),p=A.a(a._FPDFBitmap_GetFormat(b)),o=A.a(a._FPDFBitmap_GetBuffer(b)),n=A.kG(t.Z.a(a.HEAPU8),s,r,q,p,o)
if(n==null)return null
return new A.bX(n,s,r,B.am)},
fg(a,b){var s,r,q=B.C.be(b),p=q.length,o=p+1,n=A.a(a._malloc(o)),m=new Uint8Array(o)
for(s=0;s<p;++s){r=q[s]
if(!(s<o))return A.c(m,s)
m[s]=r}if(!(p<o))return A.c(m,p)
m[p]=0
A.fI(t.Z.a(a.HEAPU8),"set",m,n,t.X)
return n},
ds(a,b,c){var s,r,q,p,o=t.Z.a(a.HEAPU8),n=A.w([],t.t)
for(s=o.length,r=0;r<c;r+=2){q=b+r
if(!(q>=0&&q<s))return A.c(o,q)
p=o[q];++q
if(!(q<s))return A.c(o,q)
B.d.u(n,(p|o[q]<<8)>>>0)}return A.fb(n)},
eI(a,b){var s=t.A.a(a.HEAP32),r=B.c.l(b,2)
if(!(r<s.length))return A.c(s,r)
return s[r]>>>0},
b8(a,b,c){var s,r,q,p,o=A.fg(a,c)
try{s=A.a(a._FPDF_GetMetaText(b,o,0,0))
p=s
if(typeof p!=="number")return p.I()
if(p<=2)return null
r=A.a(a._malloc(s))
try{A.a(a._FPDF_GetMetaText(b,o,r,s))
p=s
if(typeof p!=="number")return p.a0()
q=A.ds(a,r,p-2)
p=J.Q(q)===0?null:q
return p}finally{a._free(r)}}finally{a._free(o)}},
hQ(a,b,c){var s,r,q,p,o=A.a(a._FPDF_GetFileIdentifier(b,c,0,0))
if(J.d(o,0))return null
s=A.a(a._malloc(o))
try{A.a(a._FPDF_GetFileIdentifier(b,c,s,o))
r=t.Z.a(a.HEAPU8)
q=s
p=o
if(typeof q!=="number")return q.j()
if(typeof p!=="number")return A.S(p)
p=new Uint8Array(A.hE(B.i.a1(r,s,q+p)))
return p}finally{a._free(s)}},
kT(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h=A.a(a._FPDF_LoadPage(b,c))
if(J.d(h,0))return new A.br(c,"",!1,!1)
try{s=A.a(a._FPDFText_LoadPage(h))
if(J.d(s,0))return new A.br(c,"",!1,!1)
try{r=A.a(a._FPDFText_CountChars(s))
q=!1
p=A.fO(t.S)
o=0
for(;;){j=o
i=r
if(typeof j!=="number")return j.F()
if(typeof i!=="number")return A.S(i)
if(!(j<i))break
if(A.a(a._FPDFText_HasUnicodeMapError(s,o))!==0)q=!0
if(A.a(a._FPDFText_IsHyphen(s,o))!==0)J.a4(p,o)
j=o
if(typeof j!=="number")return j.j()
o=j+1}n=null
j=r
if(typeof j!=="number")return j.I()
if(j<=0)n=""
else{j=r
if(typeof j!=="number")return j.j()
m=A.a(a._malloc((j+1)*2))
try{l=A.a(a._FPDFText_GetText(s,0,r,m))
j=l
if(typeof j!=="number")return j.I()
if(j<=0)n=""
else{j=l
if(typeof j!=="number")return j.a0()
n=A.ds(a,m,(j-1)*2)}}finally{a._free(m)}}k=p.a===0?n:A.kv(n,p)
j=q
i=r
if(typeof i!=="number")return i.P()
return new A.br(c,k,j,i>0)}finally{a._FPDFText_ClosePage(s)}}finally{a._FPDF_ClosePage(h)}},
kv(a,b){var s,r,q,p,o,n=new A.b1("")
for(s=a.length,r=!1,q=0;q<s;++q){p=a[q]
if(r)o=p==="\n"||p==="\r"||p===" "
else o=!1
r=!1
if(o)continue
if(b.aJ(0,q)){r=!0
continue}n.a+=p}s=n.a
return s.charCodeAt(0)==0?s:s},
kR(a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4=A.a(a5._FPDF_LoadPage(a6,a7))
if(J.d(a4,0))return B.M
try{s=A.a(a5._FPDFPage_GetAnnotCount(a4))
r=A.f5(s,null,!1,t.k)
a1=t.S
q=A.fN(a1,a1)
p=0
for(;;){a1=p
a2=s
if(typeof a1!=="number")return a1.F()
if(typeof a2!=="number")return A.S(a2)
if(!(a1<a2))break
A:{o=A.a(a5._FPDFPage_GetAnnot(a4,p))
if(J.d(o,0))break A
n=A.a(a5._FPDFAnnot_GetSubtype(o))
if(J.d(n,16)){J.bh(q,p,o)
break A}try{m=A.fl(a5,o,"Contents")
l=A.fl(a5,o,"T")
k=A.fl(a5,o,"M")
j=A.a(a5._FPDFAnnot_GetFlags(o))
i=A.hP(a5,o)
h=A.hO(a5,o,0)
J.bh(r,p,A.jF(o,l,h,m,a6,j,A.f7(k),a5,a7,a4,i,n))}finally{a5._FPDFPage_CloseAnnot(o)}}a1=p
if(typeof a1!=="number")return a1.j()
p=a1+1}g=A.fg(a5,"IRT")
try{for(a1=q,a1=new A.bN(a1,A.F(a1).h("bN<1,2>")).gC(0);a1.v();){a2=a1.d
a2.toString
f=a2
e=f.b
try{d=A.a(a5._FPDFAnnot_GetLinkedAnnot(e,g))
if(!J.d(d,0))try{c=A.a(a5._FPDFPage_GetAnnotIndex(a4,d))
a2=c
if(typeof a2!=="number")return a2.bD()
if(a2>=0){a2=c
a3=s
if(typeof a2!=="number")return a2.F()
if(typeof a3!=="number")return A.S(a3)
a2=a2<a3&&J.dx(r,c)!=null}else a2=!1
if(a2){b=A.hP(a5,e)
a=A.a(a5._FPDFAnnot_GetFlags(e))
a0=new A.d1(b,a)
a2=J.dx(r,c)
a2.toString
J.bh(r,c,A.kA(a2,a0))}}finally{a5._FPDFPage_CloseAnnot(d)}}finally{a5._FPDFPage_CloseAnnot(e)}}}finally{a5._free(g)}a1=r
a2=A.E(a1)
a3=a2.h("c3<1>")
a3=A.fD(new A.c3(a1,a2.h("ba(1)").a(new A.eS()),a3),a3.h("f.E"),t.e)
a1=A.U(a3,A.F(a3).h("f.E"))
return a1}finally{a5._FPDF_ClosePage(a4)}},
fl(a,b,c){var s,r,q,p,o=A.fg(a,c)
try{s=A.a(a._FPDFAnnot_GetStringValue(b,o,0,0))
p=s
if(typeof p!=="number")return p.I()
if(p<=2)return null
r=A.a(a._malloc(s))
try{A.a(a._FPDFAnnot_GetStringValue(b,o,r,s))
p=s
if(typeof p!=="number")return p.a0()
q=A.ds(a,r,p-2)
p=J.Q(q)===0?null:q
return p}finally{a._free(r)}}finally{a._free(o)}},
hP(a,b){var s,r,q,p,o,n,m=A.a(a._malloc(16))
try{s=A.a(a._FPDFAnnot_GetRect(b,m))
if(J.d(s,0))return null
r=t.E
q=r.a(a.HEAPF32)
p=B.c.l(m,2)
if(!(p<q.length))return A.c(q,p)
p=q[p]
q=m
if(typeof q!=="number")return q.j()
o=r.a(a.HEAPF32)
q=B.b.l(q+4,2)
if(!(q<o.length))return A.c(o,q)
q=o[q]
o=m
if(typeof o!=="number")return o.j()
n=r.a(a.HEAPF32)
o=B.b.l(o+8,2)
if(!(o<n.length))return A.c(n,o)
o=n[o]
n=m
if(typeof n!=="number")return n.j()
r=r.a(a.HEAPF32)
n=B.b.l(n+12,2)
if(!(n<r.length))return A.c(r,n)
n=r[n]
return new A.a5(p,n,o,q)}finally{a._free(m)}},
hO(a,b,c){var s,r,q,p,o,n,m,l=A.a(a._malloc(16)),k=l,j=l
if(typeof j!=="number")return j.j()
s=j+4
j=l
if(typeof j!=="number")return j.j()
r=j+8
j=l
if(typeof j!=="number")return j.j()
q=j+12
try{p=A.du(a,"_FPDFAnnot_GetColor",[b,c,k,s,r,q],t.S)
if(J.d(p,0))return null
j=A.eI(a,k)
o=A.eI(a,s)
n=A.eI(a,r)
m=A.eI(a,q)
return new A.cV(j,o,n,m)}finally{a._free(l)}},
kb(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=A.a(a._FPDFAnnot_CountAttachmentPoints(b))
if(J.d(e,0))return B.O
s=A.w([],t.q)
r=A.a(a._malloc(32))
try{q=0
o=t.E
for(;;){n=q
m=e
if(typeof n!=="number")return n.F()
if(typeof m!=="number")return A.S(m)
if(!(n<m))break
A:{p=A.a(a._FPDFAnnot_GetAttachmentPoints(b,q,r))
if(J.d(p,0))break A
n=o.a(a.HEAPF32)
m=B.c.l(r,2)
if(!(m<n.length))return A.c(n,m)
m=n[m]
n=r
if(typeof n!=="number")return n.j()
l=o.a(a.HEAPF32)
n=B.b.l(n+4,2)
if(!(n<l.length))return A.c(l,n)
n=l[n]
l=r
if(typeof l!=="number")return l.j()
k=o.a(a.HEAPF32)
l=B.b.l(l+8,2)
if(!(l<k.length))return A.c(k,l)
l=k[l]
k=r
if(typeof k!=="number")return k.j()
j=o.a(a.HEAPF32)
k=B.b.l(k+12,2)
if(!(k<j.length))return A.c(j,k)
k=j[k]
j=r
if(typeof j!=="number")return j.j()
i=o.a(a.HEAPF32)
j=B.b.l(j+16,2)
if(!(j<i.length))return A.c(i,j)
j=i[j]
i=r
if(typeof i!=="number")return i.j()
h=o.a(a.HEAPF32)
i=B.b.l(i+20,2)
if(!(i<h.length))return A.c(h,i)
i=h[i]
h=r
if(typeof h!=="number")return h.j()
g=o.a(a.HEAPF32)
h=B.b.l(h+24,2)
if(!(h<g.length))return A.c(g,h)
h=g[h]
g=r
if(typeof g!=="number")return g.j()
f=o.a(a.HEAPF32)
g=B.b.l(g+28,2)
if(!(g<f.length))return A.c(f,g)
J.a4(s,new A.av(new A.C(m,n),new A.C(l,k),new A.C(j,i),new A.C(h,f[g])))}n=q
if(typeof n!=="number")return n.j()
q=n+1}}finally{a._free(r)}return s},
kj(a,b,a0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c
if(a0.length===0)return null
s=A.a(a._FPDFText_LoadPage(b))
if(J.d(s,0))return null
try{r=A.w([],t.s)
for(h=a0.length,g=0;g<a0.length;a0.length===h||(0,A.cv)(a0),++g){q=a0[g]
p=q.a.a
o=q.a.a
n=q.a.b
m=q.a.b
for(f=[q.b,q.c,q.d],e=0;e<3;++e){l=f[e]
d=l.a
c=p
if(typeof c!=="number")return A.S(c)
if(d<c)p=l.a
d=l.a
c=o
if(typeof c!=="number")return A.S(c)
if(d>c)o=l.a
d=l.b
c=n
if(typeof c!=="number")return A.S(c)
if(d>c)n=l.b
d=l.b
c=m
if(typeof c!=="number")return A.S(c)
if(d<c)m=l.b}k=A.a(a._FPDFText_GetBoundedText.apply(a,[s,p,n,o,m,0,0]))
f=k
if(typeof f!=="number")return f.I()
if(f<=0)continue
f=k
if(typeof f!=="number")return f.E()
j=A.a(a._malloc(f*2))
try{i=A.a(a._FPDFText_GetBoundedText.apply(a,[s,p,n,o,m,j,k]))
f=i
if(typeof f!=="number")return f.I()
if(f<=0)continue
f=i
if(typeof f!=="number")return f.E()
J.a4(r,A.ds(a,j,f*2))}finally{a._free(j)}}h=J.iu(r," ")
return h}finally{a._FPDFText_ClosePage(s)}},
kg(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=A.a(a._FPDFAnnot_GetInkListCount(b))
if(f===0)return B.N
s=A.w([],t.B)
r=0
l=t.E
k=t.Q
for(;;){j=r
if(typeof j!=="number")return j.F()
if(!(j<f))break
A:{q=A.a(a._FPDFAnnot_GetInkListPath(b,r,0,0))
if(J.d(q,0)){J.a4(s,B.q)
break A}j=q
if(typeof j!=="number")return j.E()
p=A.a(a._malloc(j*8))
try{o=A.a(a._FPDFAnnot_GetInkListPath(b,r,p,q))
n=A.w([],k)
m=0
for(;;){j=m
i=o
if(typeof j!=="number")return j.F()
if(typeof i!=="number")return A.S(i)
if(!(j<i))break
j=p
i=m
if(typeof i!=="number")return i.E()
if(typeof j!=="number")return j.j()
h=l.a(a.HEAPF32)
i=B.b.l(j+i*8,2)
if(!(i<h.length))return A.c(h,i)
i=h[i]
h=p
j=m
if(typeof j!=="number")return j.E()
if(typeof h!=="number")return h.j()
g=l.a(a.HEAPF32)
j=B.b.l(h+j*8+4,2)
if(!(j<g.length))return A.c(g,j)
J.a4(n,new A.C(i,g[j]))
j=m
if(typeof j!=="number")return j.j()
m=j+1}J.a4(s,n)}finally{a._free(p)}}j=r
if(typeof j!=="number")return j.j()
r=j+1}return s},
kc(a,b){var s,r,q,p,o,n,m,l,k,j=A.a(a._FPDFAnnot_GetVertices(b,0,0))
if(J.d(j,0))return B.q
o=j
if(typeof o!=="number")return o.E()
s=A.a(a._malloc(o*8))
try{r=A.a(a._FPDFAnnot_GetVertices(b,s,j))
q=A.w([],t.Q)
p=0
o=t.E
for(;;){n=p
m=r
if(typeof n!=="number")return n.F()
if(typeof m!=="number")return A.S(m)
if(!(n<m))break
n=s
m=p
if(typeof m!=="number")return m.E()
if(typeof n!=="number")return n.j()
l=o.a(a.HEAPF32)
m=B.b.l(n+m*8,2)
if(!(m<l.length))return A.c(l,m)
m=l[m]
l=s
n=p
if(typeof n!=="number")return n.E()
if(typeof l!=="number")return l.j()
k=o.a(a.HEAPF32)
n=B.b.l(l+n*8+4,2)
if(!(n<k.length))return A.c(k,n)
J.a4(q,new A.C(m,k[n]))
n=p
if(typeof n!=="number")return n.j()
p=n+1}return q}finally{a._free(s)}},
kh(a,b){var s,r,q,p,o,n,m=A.a(a._malloc(16))
try{r=m
if(typeof r!=="number")return r.j()
s=A.a(a._FPDFAnnot_GetLine(b,m,r+8))
if(J.d(s,0))return new A.bw(null,null)
r=t.E
q=r.a(a.HEAPF32)
p=B.c.l(m,2)
if(!(p<q.length))return A.c(q,p)
p=q[p]
q=m
if(typeof q!=="number")return q.j()
o=r.a(a.HEAPF32)
q=B.b.l(q+4,2)
if(!(q<o.length))return A.c(o,q)
q=o[q]
o=m
if(typeof o!=="number")return o.j()
n=r.a(a.HEAPF32)
o=B.b.l(o+8,2)
if(!(o<n.length))return A.c(n,o)
o=n[o]
n=m
if(typeof n!=="number")return n.j()
r=r.a(a.HEAPF32)
n=B.b.l(n+12,2)
if(!(n<r.length))return A.c(r,n)
n=r[n]
return new A.bw(new A.C(o,n),new A.C(p,q))}finally{a._free(m)}},
ki(a,b,c){var s,r=A.a(a._FPDFAnnot_GetLink(c))
if(r===0)return null
s=A.a(a._FPDFLink_GetAction(r))
if(s===0)return null
if(A.a(a._FPDFAction_GetType(s))!==3)return null
return A.hN(a,b,s)},
hN(a,b,c){var s,r,q,p,o,n=A.a(a._FPDFAction_GetURIPath(b,c,0,0))
if(J.d(n,0))return null
s=A.a(a._malloc(n))
try{A.a(a._FPDFAction_GetURIPath(b,c,s,n))
r=t.Z.a(a.HEAPU8)
p=s
o=n
if(typeof p!=="number")return p.j()
if(typeof o!=="number")return A.S(o)
q=A.fb(J.iw(r,s,p+o-1))
p=J.Q(q)===0?null:q
return p}finally{a._free(s)}},
fh(a){var s
A:{if(1===a){s=B.U
break A}if(2===a){s=B.V
break A}if(3===a){s=B.a1
break A}if(4===a){s=B.a2
break A}if(5===a){s=B.a3
break A}if(6===a){s=B.a4
break A}if(7===a){s=B.a5
break A}if(8===a){s=B.a6
break A}if(9===a){s=B.a7
break A}if(10===a){s=B.a8
break A}if(11===a){s=B.W
break A}if(12===a){s=B.X
break A}if(13===a){s=B.Y
break A}if(15===a){s=B.Z
break A}if(16===a){s=B.a_
break A}s=B.a0
break A}return s},
jF(a,b,c,d,e,f,g,h,i,a0,a1,a2){var s,r,q,p,o,n,m,l,k,j=null
if(a2===9||a2===10||a2===11||a2===12){s=A.fh(a2)
r=A.kb(h,a)
return A.fW(b,c,d,f,A.kj(h,a0,r),g,i,j,r,a1,s)}if(a2===5||a2===6){s=A.fh(a2)
return A.fY(b,c,d,f,A.hO(h,a,1),g,i,j,a1,s)}switch(a2){case 1:return A.h_(b,c,d,f,g,i,j,a1)
case 2:return A.fV(b,c,d,f,g,i,j,a1,A.ki(h,e,a))
case 3:return A.fS(b,c,d,f,g,i,j,a1)
case 4:q=A.kh(h,a)
p=q.b
o=q.a
if(p==null){n=a1==null
m=n?j:a1.a
if(m==null)m=0
n=n?j:a1.b
l=new A.C(m,n==null?0:n)}else l=p
if(o==null){n=a1==null
m=n?j:a1.c
if(m==null)m=0
n=n?j:a1.d
k=new A.C(m,n==null?0:n)}else k=o
return A.fU(b,c,d,f,k,l,g,i,j,a1)
case 7:case 8:return A.fX(b,c,d,f,g,i,j,a1,A.fh(a2),A.kc(h,a))
case 13:return A.fZ(b,c,d,f,g,i,j,a1)
case 15:return A.fT(b,c,d,f,g,i,j,a1,A.kg(h,a))
default:return A.h0(b,c,d,f,g,i,j,a2,a1)}},
kA(a,b){var s
A:{if(a instanceof A.b_){s=A.h_(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d)
break A}if(a instanceof A.aS){s=A.fS(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d)
break A}if(a instanceof A.aW){s=A.fW(a.c,a.e,a.b,a.r,a.z,a.f,a.a,b,a.y,a.d,a.x)
break A}if(a instanceof A.aY){s=A.fY(a.c,a.e,a.b,a.r,a.y,a.f,a.a,b,a.d,a.x)
break A}if(a instanceof A.aU){s=A.fU(a.c,a.e,a.b,a.r,a.y,a.x,a.f,a.a,b,a.d)
break A}if(a instanceof A.aT){s=A.fT(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d,a.x)
break A}if(a instanceof A.aX){s=A.fX(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d,a.x,a.y)
break A}if(a instanceof A.aV){s=A.fV(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d,a.x)
break A}if(a instanceof A.aZ){s=A.fZ(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d)
break A}if(a instanceof A.b0){s=A.h0(a.c,a.e,a.b,a.r,a.f,a.a,b,a.x,a.d)
break A}s=null}return s},
kS(a2,a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=A.a(a2._FPDF_LoadPage(a3,a4))
if(J.d(a1,0))return B.K
try{s=A.a(a2._FPDFPage_CountObjects(a1))
r=A.w([],t.W)
q=0
i=t.A
h=t.E
for(;;){g=q
f=s
if(typeof g!=="number")return g.F()
if(typeof f!=="number")return A.S(f)
if(!(g<f))break
A:{p=A.a(a2._FPDFPage_GetObject(a1,q))
if(J.d(p,0))break A
if(A.a(a2._FPDFPageObj_GetType(p))!==3)break A
o=A.a(a2._malloc(28))
n=A.a(a2._FPDFImageObj_GetImageMetadata(p,a1,o))!==0
if(!n){a2._free(o)
break A}g=i.a(a2.HEAP32)
f=B.c.l(o,2)
if(!(f<g.length))return A.c(g,f)
f=g[f]
g=o
if(typeof g!=="number")return g.j()
e=i.a(a2.HEAP32)
g=B.b.l(g+4,2)
if(!(g<e.length))return A.c(e,g)
g=e[g]
e=o
if(typeof e!=="number")return e.j()
d=h.a(a2.HEAPF32)
e=B.b.l(e+8,2)
if(!(e<d.length))return A.c(d,e)
e=d[e]
d=o
if(typeof d!=="number")return d.j()
c=h.a(a2.HEAPF32)
d=B.b.l(d+12,2)
if(!(d<c.length))return A.c(c,d)
d=c[d]
c=o
if(typeof c!=="number")return c.j()
b=i.a(a2.HEAP32)
c=B.b.l(c+16,2)
if(!(c<b.length))return A.c(b,c)
c=b[c]
b=o
if(typeof b!=="number")return b.j()
a=i.a(a2.HEAP32)
b=B.b.l(b+20,2)
if(!(b<a.length))return A.c(a,b)
b=A.jI(a[b])
a=o
if(typeof a!=="number")return a.j()
a0=i.a(a2.HEAP32)
a=B.b.l(a+24,2)
if(!(a<a0.length))return A.c(a0,a)
m=new A.d_(f>>>0,g>>>0,e,d,c>>>0,b,a0[a]>>>0)
a2._free(o)
l=A.kk(a2,p)
k=A.kf(a2,p)
j=null
if(a5)j=A.hR(a2,a3,a1,p)
g=q
f=j
f=f==null?null:f.a
e=j
e=e==null?null:e.b
d=j
d=d==null?null:d.c
J.a4(r,new A.au(a4,g,m,l,k,f,e,d))}g=q
if(typeof g!=="number")return g.j()
q=g+1}return r}finally{a2._FPDF_ClosePage(a1)}},
kW(a,b,c,d){var s,r,q,p,o
if(d<0)throw A.h(A.hb(d,"objectIndex"))
p=A.a(a._FPDF_GetPageCount(b))
if(c<0||c>=p)throw A.h(A.V(c,0,p-1,"pageIndex",null))
s=A.a(a._FPDF_LoadPage(b,c))
if(J.d(s,0))throw A.h(A.f8(B.l))
try{r=A.a(a._FPDFPage_GetObject(s,d))
if(J.d(r,0))return null
q=A.a(a._FPDFPageObj_GetType(r))
if(!J.d(q,3))return null
o=A.hR(a,b,s,r)
return o}finally{a._FPDF_ClosePage(s)}},
kk(a,b){var s,r,q,p,o,n,m=A.a(a._malloc(16))
try{r=m
if(typeof r!=="number")return r.j()
q=m
if(typeof q!=="number")return q.j()
p=m
if(typeof p!=="number")return p.j()
s=A.du(a,"_FPDFPageObj_GetBounds",[b,m,r+4,q+8,p+12],t.S)
if(J.d(s,0))return B.al
r=t.E
q=r.a(a.HEAPF32)
p=B.c.l(m,2)
if(!(p<q.length))return A.c(q,p)
p=q[p]
q=m
if(typeof q!=="number")return q.j()
o=r.a(a.HEAPF32)
q=B.b.l(q+4,2)
if(!(q<o.length))return A.c(o,q)
q=o[q]
o=m
if(typeof o!=="number")return o.j()
n=r.a(a.HEAPF32)
o=B.b.l(o+8,2)
if(!(o<n.length))return A.c(n,o)
o=n[o]
n=m
if(typeof n!=="number")return n.j()
r=r.a(a.HEAPF32)
n=B.b.l(n+12,2)
if(!(n<r.length))return A.c(r,n)
n=r[n]
return new A.a5(p,q,o,n)}finally{a._free(m)}},
kf(a,b){var s,r,q,p,o,n,m,l,k,j,i,h=A.a(a._FPDFImageObj_GetImageFilterCount(b))
if(h<=0)return B.L
s=A.w([],t.s)
r=0
m=t.Z
for(;;){l=r
if(typeof l!=="number")return l.F()
if(!(l<h))break
A:{q=A.a(a._FPDFImageObj_GetImageFilter(b,r,0,0))
l=q
if(typeof l!=="number")return l.I()
if(l<=0)break A
p=A.a(a._malloc(q))
try{A.a(a._FPDFImageObj_GetImageFilter(b,r,p,q))
o=m.a(a.HEAPU8)
l=o
k=p
j=q
if(typeof k!=="number")return k.j()
if(typeof j!=="number")return A.S(j)
i=A.a(p)
n=A.fb(new Uint8Array(l.subarray(i,A.hD(i,k+j-1,J.Q(l)))))
if(J.Q(n)!==0)J.a4(s,n)}finally{a._free(p)}}l=r
if(typeof l!=="number")return l.j()
r=l+1}return s},
hR(a,b,c,d){var s,r,q,p,o,n,m,l,k,j=A.a(a._FPDFImageObj_GetRenderedBitmap(b,c,d))
if(J.d(j,0))return null
try{s=A.a(a._FPDFBitmap_GetWidth(j))
r=A.a(a._FPDFBitmap_GetHeight(j))
q=A.a(a._FPDFBitmap_GetStride(j))
l=s
if(typeof l!=="number")return l.I()
if(!(l<=0)){l=r
if(typeof l!=="number")return l.I()
l=l<=0}else l=!0
if(l)return null
p=A.a(a._FPDFBitmap_GetBuffer(j))
l=q
k=r
if(typeof l!=="number")return l.E()
if(typeof k!=="number")return A.S(k)
o=l*k
n=J.fv(B.i.gae(t.Z.a(a.HEAPU8)),p,o)
m=A.ia(n,s,r,q)
return new A.cZ(m,s,r)}finally{a._FPDFBitmap_Destroy(j)}},
jI(a){var s
A:{if(0===a){s=B.t
break A}if(1===a){s=B.a9
break A}if(2===a){s=B.ac
break A}if(3===a){s=B.ad
break A}if(4===a){s=B.ae
break A}if(5===a){s=B.af
break A}if(6===a){s=B.ag
break A}if(7===a){s=B.ah
break A}if(8===a){s=B.ai
break A}if(9===a){s=B.aj
break A}if(10===a){s=B.aa
break A}if(11===a){s=B.ab
break A}s=B.t
break A}return s},
kX(a2,a3,a4,a5,a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=A.a(a2._FPDF_LoadPage(a3,a4))
if(J.d(a1,0))return B.k
try{s=A.a(a2._FPDFText_LoadPage(a1))
if(J.d(s,0))return B.k
try{r=new A.cB(a5)
q=A.a(a2._malloc((r.a.length+1)*2))
try{p=t.Z.a(a2.HEAPU8)
o=0
for(;;){f=o
e=r.a
if(typeof f!=="number")return f.F()
if(!(f<e.length))break
f=q
e=o
if(typeof e!=="number")return e.E()
if(typeof f!=="number")return f.j()
d=A.a(o)
c=r.a
if(!(d>=0&&d<c.length))return A.c(c,d)
J.bh(p,f+e*2,c.charCodeAt(d)&255)
d=q
c=o
if(typeof c!=="number")return c.E()
if(typeof d!=="number")return d.j()
e=A.a(o)
f=r.a
if(!(e>=0&&e<f.length))return A.c(f,e)
J.bh(p,d+c*2+1,f.charCodeAt(e)>>>8&255)
f=o
if(typeof f!=="number")return f.j()
o=f+1}f=q
e=r.a
if(typeof f!=="number")return f.j()
J.bh(p,f+e.length*2,0)
e=q
f=r.a
if(typeof e!=="number")return e.j()
J.bh(p,e+f.length*2+1,0)
n=A.a(a2._FPDFText_FindStart(s,q,a6,0))
if(J.d(n,0))return B.k
m=A.w([],t.d)
try{for(f=t.bi,e=t.cN;A.a(a2._FPDFText_FindNext(n))!==0;){l=A.a(a2._FPDFText_GetSchResultIndex(n))
k=A.a(a2._FPDFText_GetSchCount(n))
j=A.a(a2._FPDFText_CountRects(s,l,k))
i=A.w([],e)
h=A.a(a2._malloc(32))
try{g=0
for(;;){d=g
c=j
if(typeof d!=="number")return d.F()
if(typeof c!=="number")return A.S(c)
if(!(d<c))break
d=g
c=h
if(typeof c!=="number")return c.j()
b=h
if(typeof b!=="number")return b.j()
a=h
if(typeof a!=="number")return a.j()
A.a(a2._FPDFText_GetRect.apply(a2,[s,d,h,c+8,b+16,a+24]))
a=f.a(a2.HEAPF64)
b=B.c.l(h,3)
if(!(b<a.length))return A.c(a,b)
b=a[b]
a=h
if(typeof a!=="number")return a.j()
c=f.a(a2.HEAPF64)
a=B.b.l(a+8,3)
if(!(a<c.length))return A.c(c,a)
a=c[a]
c=h
if(typeof c!=="number")return c.j()
d=f.a(a2.HEAPF64)
c=B.b.l(c+16,3)
if(!(c<d.length))return A.c(d,c)
c=d[c]
d=h
if(typeof d!=="number")return d.j()
a0=f.a(a2.HEAPF64)
d=B.b.l(d+24,3)
if(!(d<a0.length))return A.c(a0,d)
J.a4(i,new A.a5(b,a0[d],c,a))
d=g
if(typeof d!=="number")return d.j()
g=d+1}}finally{a2._free(h)}J.a4(m,new A.bW(a4,l,k,i))}}finally{a2._FPDFText_FindClose(n)}return m}finally{a2._free(q)}}finally{a2._FPDFText_ClosePage(s)}}finally{a2._FPDF_ClosePage(a1)}},
hX(a,b,c,d){var s,r,q=A.w([],t.a9),p=A.a(a._FPDFBookmark_GetFirstChild(b,c))
while(p!==0){if(d.aJ(0,p))break
d.u(0,p)
s=A.kd(a,p)
r=A.ko(a,b,p)
B.d.u(q,new A.aw(s,r.a,r.c,r.b,A.hX(a,b,p,d)))
p=A.a(a._FPDFBookmark_GetNextSibling(b,p))}return q},
kd(a,b){var s,r=A.a(a._FPDFBookmark_GetTitle(b,0,0)),q=r
if(typeof q!=="number")return q.I()
if(q<=2)return""
s=A.a(a._malloc(r))
try{A.a(a._FPDFBookmark_GetTitle(b,s,r))
q=r
if(typeof q!=="number")return q.a0()
q=A.ds(a,s,q-2)
return q}finally{a._free(s)}},
ko(a,b,c){var s,r,q=null,p=A.a(a._FPDFBookmark_GetAction(c))
if(p!==0){s=A.a(a._FPDFAction_GetType(p))
if(s===1){r=A.a(a._FPDFAction_GetDest(b,p))
if(r!==0)return new A.ae(A.hS(a,b,r),A.hT(a,r),q)
return new A.ae(q,q,q)}if(s===3)return new A.ae(q,q,A.hN(a,b,p))
return new A.ae(q,q,q)}r=A.a(a._FPDFBookmark_GetDest(b,c))
if(r!==0)return new A.ae(A.hS(a,b,r),A.hT(a,r),q)
return new A.ae(q,q,q)},
hS(a,b,c){var s=A.a(a._FPDFDest_GetDestPageIndex(b,c))
return s<0?null:s},
hT(a,b){var s,r,q,p,o,n,m,l,k,j,i=A.a(a._malloc(24)),h=i,g=i
if(typeof g!=="number")return g.j()
s=g+4
g=i
if(typeof g!=="number")return g.j()
r=g+8
g=i
if(typeof g!=="number")return g.j()
q=g+12
g=i
if(typeof g!=="number")return g.j()
p=g+16
g=i
if(typeof g!=="number")return g.j()
o=g+20
try{n=A.du(a,"_FPDFDest_GetLocationInPage",[b,h,s,r,q,p,o],t.S)
if(J.d(n,0))return null
g=t.A
k=g.a(a.HEAP32)
j=B.c.l(h,2)
if(!(j<k.length))return A.c(k,j)
m=k[j]!==0
g=g.a(a.HEAP32)
j=B.c.l(s,2)
if(!(j<g.length))return A.c(g,j)
l=g[j]!==0
if(!m&&!l)return null
if(m){g=t.E.a(a.HEAPF32)
k=B.c.l(q,2)
if(!(k<g.length))return A.c(g,k)
k=g[k]
g=k}else g=0
if(l){k=t.E.a(a.HEAPF32)
j=B.c.l(p,2)
if(!(j<k.length))return A.c(k,j)
j=k[j]
k=j}else k=0
return new A.C(g,k)}finally{a._free(i)}},
eS:function eS(){},
la(){var s,r=v.G,q=new A.eZ(r,new A.et(A.fN(t.S,t.bq)))
if(typeof q=="function")A.a1(A.aF("Attempting to rewrap a JS function.",null))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.jH,q)
s[$.f0()]=q
r.addEventListener("message",s)},
ez(a,b,c){return A.jP(a,b,c)},
jP(f8,f9,g0){var s=0,r=A.hK(t.H),q,p=2,o=[],n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6,f7
var $async$ez=A.hY(function(g1,g2){if(g1===1){o.push(g2)
s=p}for(;;)switch(s){case 0:p=4
e0=f9.b
case 7:switch(e0){case"load":s=9
break
case"close":s=10
break
case"pageCount":s=11
break
case"metadata":s=12
break
case"documentInfo":s=13
break
case"pageSize":s=14
break
case"render":s=15
break
case"thumbnail":s=16
break
case"extractText":s=17
break
case"extractAnnotations":s=18
break
case"extractImages":s=19
break
case"renderImage":s=20
break
case"search":s=21
break
case"toc":s=22
break
default:s=23
break}break
case 9:if(g0.b==null)g0.sbr(A.eE(f8))
e1=g0.a
s=e1==null?24:25
break
case 24:e0=g0.b
e0.toString
s=26
return A.hz(e0,$async$ez)
case 26:e1=g2
g0.sbq(e1)
case 25:n=e1
e0=f9.d
if(0>=e0.length){q=A.c(e0,0)
s=1
break}m=e0[0]
e0=n
e2=m
e3=e2.length
e4=A.a(e0._malloc(e3))
if(e4===0)A.a1(A.bY("WASM _malloc("+e3+") returned null \u2014 out of WASM heap memory."))
A.fI(t.Z.a(e0.HEAPU8),"set",e2,e4,t.X)
h=A.a(e0._FPDF_LoadMemDocument64(e4,e3,0))
if(h===0){e0._free(e4)
A.a1(A.f8(A.a(e0._FPDF_GetLastError())===4?B.ak:B.l))}l=new A.cf(e4,h)
k=g0.d++
g0.c.q(0,k,l)
A.P(f8,new A.J(f9.a,!0,A.q(["token",k],t.N,t.z),null,null,B.e))
s=8
break
case 10:e0=f9.c
j=A.a(e0.$ti.h("4?").a(e0.a.k(0,"token")))
i=g0.c.bs(0,j)
if(i!=null&&g0.a!=null){e0=g0.a
e0.toString
e2=i.b
e3=i.a
e0._FPDF_CloseDocument(e2)
e0._free(e3)}A.P(f8,new A.J(f9.a,!0,B.r,null,null,B.e))
s=8
break
case 11:h=A.a7(g0.c,f9)
g=A.a(g0.a._FPDF_GetPageCount(h))
A.P(f8,new A.J(f9.a,!0,A.q(["count",g],t.N,t.z),null,null,B.e))
s=8
break
case 12:f=A.a7(g0.c,f9)
e0=g0.a
e0.toString
e2=f
e=new A.dP(A.b8(e0,e2,"Title"),A.b8(e0,e2,"Author"),A.b8(e0,e2,"Subject"),A.b8(e0,e2,"Keywords"),A.b8(e0,e2,"Creator"),A.b8(e0,e2,"Producer"),A.f7(A.b8(e0,e2,"CreationDate")),A.f7(A.b8(e0,e2,"ModDate")))
e2=e
A.P(f8,new A.J(f9.a,!0,A.q(["title",e2.a,"author",e2.b,"subject",e2.c,"keywords",e2.d,"creator",e2.e,"producer",e2.f,"creationDate",A.fp(e2.r),"modDate",A.fp(e2.w)],t.N,t.z),null,null,B.e))
s=8
break
case 13:d=A.a7(g0.c,f9)
e0=g0.a
e0.toString
c=A.kU(e0,d)
e0=c
A.P(f8,new A.J(f9.a,!0,A.q(["fileVersion",e0.a,"permanentId",e0.b,"changingId",e0.c],t.N,t.z),null,null,B.e))
s=8
break
case 14:b=A.a7(g0.c,f9)
e0=f9.c
a=A.a(e0.$ti.h("4?").a(e0.a.k(0,"pageIndex")))
e0=g0.a
e0.toString
a0=A.i2(e0,b,a)
e0=a0
A.P(f8,new A.J(f9.a,!0,A.q(["widthPt",e0.a,"heightPt",e0.b],t.N,t.z),null,null,B.e))
s=8
break
case 15:a1=A.a7(g0.c,f9)
a2=f9.c
e0=g0.a
e0.toString
e2=a2
e2=A.a(e2.$ti.h("4?").a(e2.a.k(0,"pageIndex")))
e3=a2
e3=A.a(e3.$ti.h("4?").a(e3.a.k(0,"pixelWidth")))
e5=a2
e5=A.a(e5.$ti.h("4?").a(e5.a.k(0,"pixelHeight")))
e6=a2
e6=A.dp(e6.$ti.h("4?").a(e6.a.k(0,"renderAnnotations")))
e7=a2
e7=A.dp(e7.$ti.h("4?").a(e7.a.k(0,"lcdText")))
e8=a2
a3=A.i3(e0,a1,e2,e3,e5,A.a(e8.$ti.h("4?").a(e8.a.k(0,"backgroundColor"))),e7,e6)
a4=A.w([],t.a)
e6=a3
e7=a4
e8=J.aC(e7)
e8.u(e7,e6.c)
A.P(f8,new A.J(f9.a,!0,A.q(["bufIndex",e8.gp(e7)-1,"pixelWidth",e6.b,"pixelHeight",e6.a],t.N,t.z),null,null,a4))
s=8
break
case 16:a5=A.a7(g0.c,f9)
a6=f9.c
e0=g0.a
e0.toString
e2=a6
e3=a6
e5=a6
a7=A.kV(e0,a5,A.a(e2.$ti.h("4?").a(e2.a.k(0,"pageIndex"))),A.dp(e3.$ti.h("4?").a(e3.a.k(0,"generateIfAbsent"))),A.a(e5.$ti.h("4?").a(e5.a.k(0,"maxDimension"))))
e0=f9.a
if(a7==null)A.P(f8,new A.J(e0,!0,B.P,null,null,B.e))
else{a8=A.w([],t.a)
e2=a7
e3=a8
e5=J.aC(e3)
e5.u(e3,e2.a)
e6=t.N
e7=t.z
A.P(f8,new A.J(e0,!0,A.q(["thumbnail",A.q(["bufIndex",e5.gp(e3)-1,"width",e2.b,"height",e2.c,"source",e2.d.b],e6,e7)],e6,e7),null,null,a8))}s=8
break
case 17:a9=A.a7(g0.c,f9)
e0=f9.c
b0=A.dq(e0.$ti.h("4?").a(e0.a.k(0,"pageIndex")))
e0=g0.a
e0.toString
b1=A.eT(e0,a9,b0)
e0=b1
e2=A.E(e0)
e3=e2.h("r<1,m<j,@>>")
b6=A.U(new A.r(e0,e2.h("m<j,@>(1)").a(new A.eA(g0,a9)),e3),e3.h("B.E"))
b2=b6
A.P(f8,new A.J(f9.a,!0,A.q(["pages",b2],t.N,t.z),null,null,B.e))
s=8
break
case 18:b3=A.a7(g0.c,f9)
e0=f9.c
b4=A.dq(e0.$ti.h("4?").a(e0.a.k(0,"pageIndex")))
e0=g0.a
e0.toString
b5=A.eT(e0,b3,b4)
e0=b5
e2=A.E(e0)
e3=e2.h("r<1,m<j,@>>")
b2=A.U(new A.r(e0,e2.h("m<j,@>(1)").a(new A.eB(g0,b3)),e3),e3.h("B.E"))
b6=b2
A.P(f8,new A.J(f9.a,!0,A.q(["pages",b6],t.N,t.z),null,null,B.e))
s=8
break
case 19:b7=A.a7(g0.c,f9)
b8=f9.c
e0=b8
b9=A.dq(e0.$ti.h("4?").a(e0.a.k(0,"pageIndex")))
e0=b8
c0=A.dp(e0.$ti.h("4?").a(e0.a.k(0,"includeBitmap")))
e0=g0.a
e0.toString
c1=A.eT(e0,b7,b9)
c2=A.w([],t.a)
e0=c1
e2=A.E(e0)
e3=e2.h("r<1,m<j,@>>")
b2=A.U(new A.r(e0,e2.h("m<j,@>(1)").a(new A.eC(g0,b7,c0,c2)),e3),e3.h("B.E"))
c3=b2
A.P(f8,new A.J(f9.a,!0,A.q(["pages",c3],t.N,t.z),null,null,c2))
s=8
break
case 20:c4=A.a7(g0.c,f9)
c5=f9.c
e0=g0.a
e0.toString
e2=c5
e3=c5
c6=A.kW(e0,c4,A.a(e2.$ti.h("4?").a(e2.a.k(0,"pageIndex"))),A.a(e3.$ti.h("4?").a(e3.a.k(0,"objectIndex"))))
e0=f9.a
if(c6==null)A.P(f8,new A.J(e0,!0,B.Q,null,null,B.e))
else{c7=A.w([],t.a)
e2=c6
e3=c7
e5=J.aC(e3)
e5.u(e3,e2.a)
e6=t.N
e7=t.z
A.P(f8,new A.J(e0,!0,A.q(["bitmap",A.q(["bufIndex",e5.gp(e3)-1,"width",e2.b,"height",e2.c],e6,e7)],e6,e7),null,null,c7))}s=8
break
case 21:c8=A.a7(g0.c,f9)
c9=f9.c
e0=c9
d0=A.ao(e0.$ti.h("4?").a(e0.a.k(0,"query")))
e0=c9
d1=A.a(e0.$ti.h("4?").a(e0.a.k(0,"flagsMask")))
e0=c9
d2=A.dq(e0.$ti.h("4?").a(e0.a.k(0,"pageIndex")))
d3=A.w([],t.bG)
if(J.Q(d0)!==0){e0=g0.a
e0.toString
d4=A.eT(e0,c8,d2)
for(e0=d4,e2=e0.length,e3=t.N,e5=t.z,e9=0;e9<e0.length;e0.length===e2||(0,A.cv)(e0),++e9){d5=e0[e9]
e6=g0.a
e6.toString
e6=A.kX(e6,c8,d5,d0,d1)
e7=e6.length
f0=0
for(;f0<e6.length;e6.length===e7||(0,A.cv)(e6),++f0){d6=e6[f0]
e8=d6
f1=e8.a
f2=e8.b
f3=e8.c
e8=e8.d
f4=A.E(e8)
f5=f4.h("r<1,m<j,@>>")
e8=A.U(new A.r(e8,f4.h("m<j,@>(1)").a(A.ka()),f5),f5.h("B.E"))
J.a4(d3,A.q(["pageIndex",f1,"charIndex",f2,"charCount",f3,"rects",e8],e3,e5))}}}A.P(f8,new A.J(f9.a,!0,A.q(["matches",d3],t.N,t.z),null,null,B.e))
s=8
break
case 22:d7=A.a7(g0.c,f9)
e0=g0.a
e0.toString
d8=A.hX(e0,d7,0,A.fO(t.S))
e0=d8
e2=A.E(e0)
e3=e2.h("r<1,m<j,@>>")
e0=A.U(new A.r(e0,e2.h("m<j,@>(1)").a(A.hM()),e3),e3.h("B.E"))
A.P(f8,new A.J(f9.a,!0,A.q(["entries",e0],t.N,t.z),null,null,B.e))
s=8
break
case 23:A.P(f8,A.hh(f9.a,new A.bs("Unknown worker op: "+e0)))
case 8:p=2
s=6
break
case 4:p=3
f7=o.pop()
d9=A.af(f7)
A.P(f8,A.hh(f9.a,d9))
s=6
break
case 3:s=2
break
case 6:case 1:return A.hB(q,r)
case 2:return A.hA(o.at(-1),r)}})
return A.hC($async$ez,r)},
a7(a,b){var s=b.c,r=a.k(0,A.a(s.$ti.h("4?").a(s.a.k(0,"token"))))
if(r==null)throw A.h(A.dS("PdfDocument has already been closed."))
return r.b},
P(a,b){var s=A.kE(b),r=s.b
a.postMessage(s.a,t.c.a(new A.bD(r,A.E(r).h("bD<1,o>"))))},
eE(a){var s=0,r=A.hK(t.m),q,p=2,o=[],n,m,l,k,j,i,h,g
var $async$eE=A.hY(function(b,c){if(b===1){o.push(c)
s=p}for(;;)switch(s){case 0:j=new A.c5(new A.D($.z,t.D),t.aY)
i={}
h=new A.eF(j)
if(typeof h=="function")A.a1(A.aF("Attempting to rewrap a JS function.",null))
m=function(d,e){return function(){return d(e)}}(A.jG,h)
m[$.f0()]=h
i.onRuntimeInitialized=m
a.Module=i
a.importScripts("pdfium.js")
p=4
s=7
return A.hz(j.a.bv(B.E,new A.eG()),$async$eE)
case 7:p=2
s=6
break
case 4:p=3
g=o.pop()
n=A.af(g)
if(n instanceof A.bs)throw g
throw A.h(A.bY("PDFium WASM module failed to initialise inside the PDFium Worker: "+A.e(n)))
s=6
break
case 3:s=2
break
case 6:k=A.ev(a.Module)
k._FPDF_InitLibraryWithConfig(0)
q=k
s=1
break
case 1:return A.hB(q,r)
case 2:return A.hA(o.at(-1),r)}})
return A.hC($async$eE,r)},
et:function et(a){var _=this
_.b=_.a=null
_.c=a
_.d=1},
eZ:function eZ(a,b){this.a=a
this.b=b},
eA:function eA(a,b){this.a=a
this.b=b},
eB:function eB(a,b){this.a=a
this.b=b},
eC:function eC(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eF:function eF(a){this.a=a},
eG:function eG(){},
hh(a,b){var s=A.kF(b)
return new A.J(a,!1,null,s.b,s.a,B.e)},
kF(a){var s
A:{if(t.G.b(a)){s=a.d
s=s==null?null:J.ap(s)
s=new A.ad(s==null?a.i(0):s,"RangeError")
break A}if(a instanceof A.a2){s=a.d
s=s==null?null:J.ap(s)
s=new A.ad(s==null?a.i(0):s,"ArgumentError")
break A}if(a instanceof A.c0){s=new A.ad(a.a,"StateError")
break A}if(a instanceof A.cY){s=new A.ad(a.a.b,"PdfExtractionException")
break A}if(a instanceof A.bs){s=new A.ad(a.a,"PdfiumException")
break A}s=new A.ad(J.ap(a),"Exception")
break A}return s},
fp(a){var s,r
if(a==null)s=null
else{s=a.a
r=a.b
s=A.q(["raw",s,"value",r==null?null:r.bw()],t.N,t.z)}return s},
eR(a){t.O.a(a)
return A.q(["left",a.a,"bottom",a.b,"right",a.c,"top",a.d],t.N,t.z)},
i1(a){return A.q(["r",a.a,"g",a.b,"b",a.c,"a",a.d],t.N,t.z)},
kO(a){t.w.a(a)
return A.q(["x",a.a,"y",a.b],t.N,t.z)},
kP(a){var s,r,q,p,o,n
t.u.a(a)
s=a.a
r=t.N
q=t.z
p=a.b
o=a.c
n=a.d
return A.q(["p1",A.q(["x",s.a,"y",s.b],r,q),"p2",A.q(["x",p.a,"y",p.b],r,q),"p3",A.q(["x",o.a,"y",o.b],r,q),"p4",A.q(["x",n.a,"y",n.b],r,q)],r,q)},
kQ(a){var s,r,q,p
t.b.a(a)
s=a.d
s=s==null?null:A.q(["x",s.a,"y",s.b],t.N,t.z)
r=a.e
q=A.E(r)
p=q.h("r<1,m<j,@>>")
r=A.U(new A.r(r,q.h("m<j,@>(1)").a(A.hM()),p),p.h("B.E"))
return A.q(["title",a.a,"pageIndex",a.b,"uri",a.c,"scrollPosition",s,"children",r],t.N,t.z)},
kM(a){var s,r,q,p,o,n,m,l=null,k="kind",j="subtype"
t.e.a(a)
s=a.d
s=s==null?l:A.eR(s)
r=a.e
r=r==null?l:A.i1(r)
q=A.fp(a.f)
p=a.w
if(p==null)p=l
else{o=p.a
o=o==null?l:A.eR(o)
p=A.q(["rect",o,"flags",p.b],t.N,t.z)}o=t.N
n=t.z
m=A.q(["pageIndex",a.a,"contents",a.b,"author",a.c,"rect",s,"color",r,"modifiedDate",q,"flags",a.r,"popup",p],o,n)
A:{if(a instanceof A.b_){s=A.ak(m,o,n)
s.q(0,k,"text")
break A}if(a instanceof A.aS){s=A.ak(m,o,n)
s.q(0,k,"freeText")
break A}if(a instanceof A.aW){s=A.ak(m,o,n)
s.q(0,k,"markup")
s.q(0,j,a.x.b)
r=a.y
q=A.E(r)
p=q.h("r<1,m<j,@>>")
r=A.U(new A.r(r,q.h("m<j,@>(1)").a(A.k9()),p),p.h("B.E"))
s.q(0,"quadPoints",r)
s.q(0,"markedText",a.z)
break A}if(a instanceof A.aY){s=A.ak(m,o,n)
s.q(0,k,"shape")
s.q(0,j,a.x.b)
r=a.y
s.q(0,"interiorColor",r==null?l:A.i1(r))
break A}if(a instanceof A.aU){s=A.ak(m,o,n)
s.q(0,k,"line")
r=a.x
s.q(0,"lineStart",A.q(["x",r.a,"y",r.b],o,n))
r=a.y
s.q(0,"lineEnd",A.q(["x",r.a,"y",r.b],o,n))
break A}if(a instanceof A.aT){s=A.ak(m,o,n)
s.q(0,k,"ink")
r=a.x
q=A.E(r)
p=q.h("r<1,n<m<j,@>>>")
r=A.U(new A.r(r,q.h("n<m<j,@>>(1)").a(new A.eP()),p),p.h("B.E"))
s.q(0,"strokes",r)
break A}if(a instanceof A.aX){s=A.ak(m,o,n)
s.q(0,k,"polygon")
s.q(0,j,a.x.b)
r=a.y
q=A.E(r)
p=q.h("r<1,m<j,@>>")
r=A.U(new A.r(r,q.h("m<j,@>(1)").a(A.hL()),p),p.h("B.E"))
s.q(0,"vertices",r)
break A}if(a instanceof A.aV){s=A.ak(m,o,n)
s.q(0,k,"link")
s.q(0,"uri",a.x)
break A}if(a instanceof A.aZ){s=A.ak(m,o,n)
s.q(0,k,"stamp")
break A}if(a instanceof A.b0){s=A.ak(m,o,n)
s.q(0,k,"unknown")
s.q(0,"rawSubtype",a.x)
break A}s=l}return s},
kN(a,b){var s=a.b,r=A.E(s),q=r.h("r<1,m<j,@>>")
s=A.U(new A.r(s,r.h("m<j,@>(1)").a(new A.eQ(b)),q),q.h("B.E"))
return A.q(["pageIndex",a.a,"images",s],t.N,t.z)},
dW:function dW(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
J:function J(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
eP:function eP(){},
eQ:function eQ(a){this.a=a},
kE(a){var s=a.f,r=A.E(s),q=r.h("r<1,aa>"),p=A.U(new A.r(s,r.h("aa(1)").a(new A.eL()),q),q.h("B.E")),o={}
o.id=a.a
o.ok=a.b
s=a.c
o.json=B.p.bh(s==null?B.r:s,null)
o.buffers=p
s=a.d
if(s!=null)o.errorType=s
s=a.e
if(s!=null)o.errorMessage=s
return new A.cg(o,p)},
ke(a){var s=t.c.a(a.buffers)
s=B.d.Y(s,new A.eH(),t.p)
s=A.U(s,s.$ti.h("B.E"))
return s},
eL:function eL(){},
eH:function eH(){},
dr(a,b,c){var s,r
if(a.length!==b.length)return!1
for(s=0;s<a.length;++s){r=a[s]
if(!(s<b.length))return A.c(b,s)
if(!J.d(r,b[s]))return!1}return!0},
f8(a){return new A.cY(a)},
h_(a,b,c,d,e,f,g,h){return new A.b_(f,c,a,h,b,e,d,g)},
fS(a,b,c,d,e,f,g,h){return new A.aS(f,c,a,h,b,e,d,g)},
fW(a,b,c,d,e,f,g,h,i,j,k){return new A.aW(k,i,e,g,c,a,j,b,f,d,h)},
fY(a,b,c,d,e,f,g,h,i,j){return new A.aY(j,e,g,c,a,i,b,f,d,h)},
fU(a,b,c,d,e,f,g,h,i,j){return new A.aU(f,e,h,c,a,j,b,g,d,i)},
fT(a,b,c,d,e,f,g,h,i){return new A.aT(i,f,c,a,h,b,e,d,g)},
iY(a,b){var s,r,q,p,o,n,m,l,k=a.length,j=b.length
if(k!==j)return!1
for(s=0;s<k;++s){r=a[s]
q=r.length
if(!(s<j))return A.c(b,s)
p=b[s]
o=p.length
if(q!==o)return!1
for(n=0;n<q;++n){m=r[n]
if(!(n<o))return A.c(p,n)
l=p[n]
if(m!==l)m=m.a===l.a&&m.b===l.b
else m=!0
if(!m)return!1}}return!0},
fX(a,b,c,d,e,f,g,h,i,j){return new A.aX(i,j,f,c,a,h,b,e,d,g)},
fV(a,b,c,d,e,f,g,h,i){return new A.aV(i,f,c,a,h,b,e,d,g)},
fZ(a,b,c,d,e,f,g,h){return new A.aZ(f,c,a,h,b,e,d,g)},
h0(a,b,c,d,e,f,g,h,i){return new A.b0(h,f,c,a,i,b,e,d,g)},
cX:function cX(a,b){this.a=a
this.b=b},
cY:function cY(a){this.a=a},
cW:function cW(a,b){this.a=a
this.b=b},
dP:function dP(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
br:function br(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
M:function M(a,b){this.a=a
this.b=b},
cV:function cV(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
a5:function a5(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
C:function C(a,b){this.a=a
this.b=b},
av:function av(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
d1:function d1(a,b){this.a=a
this.b=b},
H:function H(){},
b_:function b_(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
aS:function aS(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
aW:function aW(a,b,c,d,e,f,g,h,i,j,k){var _=this
_.x=a
_.y=b
_.z=c
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i
_.r=j
_.w=k},
aY:function aY(a,b,c,d,e,f,g,h,i,j){var _=this
_.x=a
_.y=b
_.a=c
_.b=d
_.c=e
_.d=f
_.e=g
_.f=h
_.r=i
_.w=j},
aU:function aU(a,b,c,d,e,f,g,h,i,j){var _=this
_.x=a
_.y=b
_.a=c
_.b=d
_.c=e
_.d=f
_.e=g
_.f=h
_.r=i
_.w=j},
aT:function aT(a,b,c,d,e,f,g,h,i){var _=this
_.x=a
_.a=b
_.b=c
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i},
aX:function aX(a,b,c,d,e,f,g,h,i,j){var _=this
_.x=a
_.y=b
_.a=c
_.b=d
_.c=e
_.d=f
_.e=g
_.f=h
_.r=i
_.w=j},
aV:function aV(a,b,c,d,e,f,g,h,i){var _=this
_.x=a
_.a=b
_.b=c
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i},
aZ:function aZ(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
b0:function b0(a,b,c,d,e,f,g,h,i){var _=this
_.x=a
_.a=b
_.b=c
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i},
aw:function aw(a,b,c,d,e){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e},
X:function X(a,b){this.a=a
this.b=b},
d_:function d_(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
au:function au(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
cZ:function cZ(a,b,c){this.a=a
this.b=b
this.c=c},
dQ:function dQ(a,b){this.a=a
this.b=b},
bW:function bW(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
d2:function d2(a,b){this.a=a
this.b=b},
bX:function bX(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dM:function dM(a,b,c){this.a=a
this.b=b
this.c=c},
dN:function dN(){},
dO:function dO(){},
bY(a){return new A.bs(a)},
bs:function bs(a){this.a=a},
d0:function d0(a,b){this.a=a
this.b=b},
le(a){throw A.K(new A.cO("Field '"+a+"' has been assigned during initialization."),new Error())},
iR(a,b,c,d,e,f){var s=a[b](c,d)
return s},
fI(a,b,c,d,e){return e.a(A.iR(a,b,c,d,null,null))},
jG(a){return t.Y.a(a).$0()},
jH(a,b,c){t.Y.a(a)
if(A.a(c)>=1)return a.$1(b)
return a.$0()},
du(a,b,c,d){return d.a(a[b].apply(a,c))},
ia(a,b,c,d){var s,r,q,p=b*4
if(d===p)return new Uint8Array(A.hE(a))
s=new Uint8Array(b*c*4)
for(r=0;r<c;++r){q=r*p
B.i.aS(s,q,q+p,a,r*d)}return s},
kG(a,b,c,d,e,f){var s,r,q,p,o,n,m,l,k,j,i,h,g=4
switch(e){case 4:break
case 3:break
case 2:g=3
break
default:return null}s=b*c*4
r=new Uint8Array(s)
for(q=e===4,p=a.length,o=0;o<c;++o){n=f+o*d
m=o*b*4
for(l=0;l<b;++l){k=n+l*g
j=m+l*4
if(!(k>=0&&k<p))return A.c(a,k)
i=a[k]
if(!(j>=0&&j<s))return A.c(r,j)
r[j]=i
i=j+1
h=k+1
if(!(h<p))return A.c(a,h)
h=a[h]
if(!(i<s))return A.c(r,i)
r[i]=h
h=j+2
i=k+2
if(!(i<p))return A.c(a,i)
i=a[i]
if(!(h<s))return A.c(r,h)
r[h]=i
i=j+3
if(q){h=k+3
if(!(h<p))return A.c(a,h)
h=a[h]}else h=255
if(!(i<s))return A.c(r,i)
r[i]=h}}return r},
f7(a){if(a==null||a.length===0)return null
return new A.cW(a,A.iX(a))},
iX(b1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8=null,a9=1000,b0=b1
if(J.fx(b0,"D:")||J.fx(b0,"d:"))b0=J.fy(b0,2)
b0=J.ix(b0)
if(J.Q(b0)<4)return a8
try{s=A.bq(b0,0,4)
if(s==null)return a8
if(J.Q(b0)>=6){f=A.bq(b0,4,6)
e=f==null?1:f}else e=1
r=e
if(J.Q(b0)>=8){f=A.bq(b0,6,8)
d=f==null?1:f}else d=1
q=d
if(J.Q(b0)>=10){f=A.bq(b0,8,10)
c=f==null?0:f}else c=0
p=c
if(J.Q(b0)>=12){f=A.bq(b0,10,12)
b=f==null?0:f}else b=0
o=b
if(J.Q(b0)>=14){f=A.bq(b0,12,14)
a=f==null?0:f}else a=0
n=a
f=r
if(typeof f!=="number")return f.F()
if(!(f<1)){f=r
if(typeof f!=="number")return f.P()
f=f>12}else f=!0
if(f)return a8
f=q
if(typeof f!=="number")return f.F()
if(!(f<1)){f=q
if(typeof f!=="number")return f.P()
f=f>31}else f=!0
if(f)return a8
f=p
if(typeof f!=="number")return f.P()
a0=!0
if(!(f>23)){f=o
if(typeof f!=="number")return f.P()
if(!(f>59)){f=n
if(typeof f!=="number")return f.P()
f=f>59}else f=a0}else f=a0
if(f)return a8
m=B.j
if(J.Q(b0)>14){l=J.dx(b0,14)
if(J.d(l,"Z")||J.d(l,"z"))m=B.j
else if(J.d(l,"+")||J.d(l,"-")){k=J.fy(b0,15)
j=A.fR(k,0)
i=A.fR(k,2)
f=j
if(f==null)f=0
if(typeof f!=="number")return f.E()
a0=i
if(a0==null)a0=0
if(typeof a0!=="number")return A.S(a0)
h=f*60+a0
m=new A.aL(6e7*(J.d(l,"+")?h:J.iq(h)))}}g=A.iF(s,r,q,p,o,n)
f=g
a0=0-t.x.a(m).a
a1=B.c.a_(a0,a9)
a2=B.c.O(a0-a1,a9)
a3=f.b+a1
a4=B.c.a_(a3,a9)
a5=B.c.O(a3-a4,a9)
a6=f.a+a5+a2
if(a6<-864e13||a6>864e13)A.a1(A.V(a6,-864e13,864e13,"millisecondsSinceEpoch",a8))
if(a6===864e13&&a4!==0)A.a1(A.dy(a4,"microsecond","Time including microseconds is outside valid range"))
A.eM(!0,"isUtc",t.y)
return new A.bF(a6,a4,!0)}catch(a7){return a8}},
bq(a,b,c){var s=a.length
if(c>s)c=s
if(b>=c)return null
return A.j_(B.h.L(a,b,c),null)},
fR(a,b){var s=A.j4("[^0-9]")
return A.bq(A.ld(a,s,""),b,b+2)}},B={}
var w=[A,J,B]
var $={}
A.f3.prototype={}
J.cH.prototype={
n(a,b){return a===b},
gm(a){return A.d5(a)},
i(a){return"Instance of '"+A.d6(a)+"'"},
gD(a){return A.bb(A.fi(this))}}
J.cJ.prototype={
i(a){return String(a)},
gm(a){return a?519018:218159},
gD(a){return A.bb(t.y)},
$iu:1,
$iba:1}
J.bI.prototype={
n(a,b){return null==b},
i(a){return"null"},
gm(a){return 0},
$iu:1,
$iG:1}
J.bL.prototype={$iA:1}
J.ar.prototype={
gm(a){return 0},
i(a){return String(a)}}
J.d3.prototype={}
J.b2.prototype={}
J.ai.prototype={
i(a){var s=a[$.ic()]
if(s==null)s=a[$.f0()]
if(s==null)return this.aV(a)
return"JavaScript function for "+J.ap(s)},
$iaM:1}
J.bk.prototype={
gm(a){return 0},
i(a){return String(a)}}
J.bl.prototype={
gm(a){return 0},
i(a){return String(a)}}
J.v.prototype={
u(a,b){A.E(a).c.a(b)
a.$flags&1&&A.aE(a,29)
a.push(b)},
Y(a,b,c){var s=A.E(a)
return new A.r(a,s.t(c).h("1(2)").a(b),s.h("@<1>").t(c).h("r<1,2>"))},
bo(a,b){var s,r=A.f5(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.q(r,s,A.e(a[s]))
return r.join(b)},
G(a,b){if(!(b>=0&&b<a.length))return A.c(a,b)
return a[b]},
gB(a){return a.length===0},
gM(a){return a.length!==0},
i(a){return A.f2(a,"[","]")},
gC(a){return new J.aG(a,a.length,A.E(a).h("aG<1>"))},
gm(a){return A.d5(a)},
gp(a){return a.length},
k(a,b){if(!(b>=0&&b<a.length))throw A.h(A.dv(a,b))
return a[b]},
q(a,b,c){A.E(a).c.a(c)
a.$flags&2&&A.aE(a)
if(!(b>=0&&b<a.length))throw A.h(A.dv(a,b))
a[b]=c},
$il:1,
$if:1,
$in:1}
J.cI.prototype={
bz(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.d6(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.dE.prototype={}
J.aG.prototype={
gA(){var s=this.d
return s==null?this.$ti.c.a(s):s},
v(){var s,r=this,q=r.a,p=q.length
if(r.b!==p){q=A.cv(q)
throw A.h(q)}s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0},
$iR:1}
J.bK.prototype={
ag(a,b){var s
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=B.c.gal(b)
if(this.gal(a)===s)return 0
if(this.gal(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gal(a){return a===0?1/a<0:a<0},
aM(a){if(a>0){if(a!==1/0)return Math.round(a)}else if(a>-1/0)return 0-Math.round(0-a)
throw A.h(A.dc(""+a+".round()"))},
aH(a,b,c){if(B.c.ag(b,c)>0)throw A.h(A.ct(b))
if(this.ag(a,b)<0)return b
if(this.ag(a,c)>0)return c
return a},
bx(a,b){var s,r,q,p,o
if(b<2||b>36)throw A.h(A.V(b,2,36,"radix",null))
s=a.toString(b)
r=s.length
q=r-1
if(!(q>=0))return A.c(s,q)
if(s.charCodeAt(q)!==41)return s
p=/^([\da-z]+)(?:\.([\da-z]+))?\(e\+(\d+)\)$/.exec(s)
if(p==null)A.a1(A.dc("Unexpected toString result: "+s))
r=p.length
if(1>=r)return A.c(p,1)
s=p[1]
if(3>=r)return A.c(p,3)
o=+p[3]
r=p[2]
if(r!=null){s+=r
o-=r.length}return s+B.h.E("0",o)},
i(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gm(a){var s,r,q,p,o=a|0
if(a===o)return o&536870911
s=Math.abs(a)
r=Math.log(s)/0.6931471805599453|0
q=Math.pow(2,r)
p=s<1?s/q:q/s
return((p*9007199254740992|0)+(p*3542243181176521|0))*599197+r*1259&536870911},
a_(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
return s+b},
O(a,b){return(a|0)===a?a/b|0:this.b9(a,b)},
b9(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.h(A.dc("Result of truncating division is "+A.e(s)+": "+A.e(a)+" ~/ "+b))},
l(a,b){var s
if(a>0)s=this.b8(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
b8(a,b){return b>31?0:a>>>b},
gD(a){return A.bb(t.o)},
$it:1,
$ibg:1}
J.bj.prototype={
aQ(a){return-a},
gD(a){return A.bb(t.S)},
$iu:1,
$ib:1}
J.bJ.prototype={
gD(a){return A.bb(t.i)},
$iu:1}
J.aN.prototype={
aT(a,b){var s=b.length
if(s>a.length)return!1
return b===a.substring(0,s)},
L(a,b,c){return a.substring(b,A.hc(b,c,a.length))},
aU(a,b){return this.L(a,b,null)},
by(a){var s,r,q,p=a.trim(),o=p.length
if(o===0)return p
if(0>=o)return A.c(p,0)
if(p.charCodeAt(0)===133){s=J.iS(p,1)
if(s===o)return""}else s=0
r=o-1
if(!(r>=0))return A.c(p,r)
q=p.charCodeAt(r)===133?J.iT(p,r):o
if(s===0&&q===o)return p
return p.substring(s,q)},
E(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.h(B.B)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
aK(a,b,c){var s=b-a.length
if(s<=0)return a
return this.E(c,s)+a},
i(a){return a},
gm(a){var s,r,q
for(s=a.length,r=0,q=0;q<s;++q){r=r+a.charCodeAt(q)&536870911
r=r+((r&524287)<<10)&536870911
r^=r>>6}r=r+((r&67108863)<<3)&536870911
r^=r>>11
return r+((r&16383)<<15)&536870911},
gD(a){return A.bb(t.N)},
gp(a){return a.length},
k(a,b){if(b>=a.length)throw A.h(A.dv(a,b))
return a[b]},
$iu:1,
$idL:1,
$ij:1}
A.az.prototype={
gC(a){return new A.bC(J.cw(this.gN()),A.F(this).h("bC<1,2>"))},
gp(a){return J.Q(this.gN())},
gB(a){return J.ir(this.gN())},
gM(a){return J.is(this.gN())},
G(a,b){return A.F(this).y[1].a(J.fw(this.gN(),b))},
i(a){return J.ap(this.gN())}}
A.bC.prototype={
v(){return this.a.v()},
gA(){return this.$ti.y[1].a(this.a.gA())},
$iR:1}
A.aH.prototype={
gN(){return this.a}}
A.c7.prototype={$il:1}
A.c6.prototype={
k(a,b){return this.$ti.y[1].a(J.dx(this.a,b))},
$il:1,
$in:1}
A.bD.prototype={
gN(){return this.a}}
A.aI.prototype={
af(a,b,c){return new A.aI(this.a,this.$ti.h("@<1,2>").t(b).t(c).h("aI<1,2,3,4>"))},
k(a,b){return this.$ti.h("4?").a(this.a.k(0,b))},
J(a,b){this.a.J(0,new A.dA(this,this.$ti.h("~(3,4)").a(b)))},
gK(){var s=this.$ti
return A.fD(this.a.gK(),s.c,s.y[2])},
gp(a){var s=this.a
return s.gp(s)},
gB(a){var s=this.a
return s.gB(s)}}
A.dA.prototype={
$2(a,b){var s=this.a.$ti
s.c.a(a)
s.y[1].a(b)
this.b.$2(s.y[2].a(a),s.y[3].a(b))},
$S(){return this.a.$ti.h("~(1,2)")}}
A.cO.prototype={
i(a){return"LateInitializationError: "+this.a}}
A.cB.prototype={
gp(a){return this.a.length},
k(a,b){var s=this.a
if(!(b>=0&&b<s.length))return A.c(s,b)
return s.charCodeAt(b)}}
A.dR.prototype={}
A.l.prototype={}
A.B.prototype={
gC(a){var s=this
return new A.aP(s,s.gp(s),A.F(s).h("aP<B.E>"))},
gB(a){return this.gp(this)===0},
bn(a){var s,r,q=this,p=q.gp(q)
for(s=0,r="";s<p;++s){r+=A.e(q.G(0,s))
if(p!==q.gp(q))throw A.h(A.aJ(q))}return r.charCodeAt(0)==0?r:r}}
A.aP.prototype={
gA(){var s=this.d
return s==null?this.$ti.c.a(s):s},
v(){var s,r=this,q=r.a,p=J.cu(q),o=p.gp(q)
if(r.b!==o)throw A.h(A.aJ(q))
s=r.c
if(s>=o){r.d=null
return!1}r.d=p.G(q,s);++r.c
return!0},
$iR:1}
A.aQ.prototype={
gC(a){var s=this.a
return new A.bQ(s.gC(s),this.b,A.F(this).h("bQ<1,2>"))},
gp(a){var s=this.a
return s.gp(s)},
gB(a){var s=this.a
return s.gB(s)},
G(a,b){var s=this.a
return this.b.$1(s.G(s,b))}}
A.bG.prototype={$il:1}
A.bQ.prototype={
v(){var s=this,r=s.b
if(r.v()){s.a=s.c.$1(r.gA())
return!0}s.a=null
return!1},
gA(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iR:1}
A.r.prototype={
gp(a){return J.Q(this.a)},
G(a,b){return this.b.$1(J.fw(this.a,b))}}
A.c3.prototype={
gC(a){return new A.c4(J.cw(this.a),this.b,this.$ti.h("c4<1>"))}}
A.c4.prototype={
v(){var s,r
for(s=this.a,r=this.b;s.v();)if(r.$1(s.gA()))return!0
return!1},
gA(){return this.a.gA()},
$iR:1}
A.T.prototype={}
A.c1.prototype={}
A.bv.prototype={}
A.cq.prototype={}
A.cf.prototype={$r:"+bufPtr,docPtr(1,2)",$s:1}
A.bw.prototype={$r:"+end,start(1,2)",$s:2}
A.cg.prototype={$r:"+message,transfer(1,2)",$s:3}
A.ad.prototype={$r:"+message,type(1,2)",$s:4}
A.ae.prototype={$r:"+pageIndex,scrollPosition,uri(1,2,3)",$s:5}
A.ch.prototype={$r:"+pixelHeight,pixelWidth,pixels(1,2,3)",$s:6}
A.bE.prototype={
af(a,b,c){var s=A.F(this)
return A.fP(this,s.c,s.y[1],b,c)},
gB(a){return this.gp(this)===0},
i(a){return A.f6(this)},
$im:1}
A.aK.prototype={
gp(a){return this.b.length},
gav(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
bd(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
k(a,b){if(!this.bd(b))return null
return this.b[this.a[b]]},
J(a,b){var s,r,q,p
this.$ti.h("~(1,2)").a(b)
s=this.gav()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])},
gK(){return new A.c8(this.gav(),this.$ti.h("c8<1>"))}}
A.c8.prototype={
gp(a){return this.a.length},
gB(a){return 0===this.a.length},
gM(a){return 0!==this.a.length},
gC(a){var s=this.a
return new A.c9(s,s.length,this.$ti.h("c9<1>"))}}
A.c9.prototype={
gA(){var s=this.d
return s==null?this.$ti.c.a(s):s},
v(){var s=this,r=s.c
if(r>=s.b){s.d=null
return!1}s.d=s.a[r]
s.c=r+1
return!0},
$iR:1}
A.bZ.prototype={}
A.dT.prototype={
H(a){var s,r,q=this,p=new RegExp(q.a).exec(a)
if(p==null)return null
s=Object.create(null)
r=q.b
if(r!==-1)s.arguments=p[r+1]
r=q.c
if(r!==-1)s.argumentsExpr=p[r+1]
r=q.d
if(r!==-1)s.expr=p[r+1]
r=q.e
if(r!==-1)s.method=p[r+1]
r=q.f
if(r!==-1)s.receiver=p[r+1]
return s}}
A.bV.prototype={
i(a){return"Null check operator used on a null value"}}
A.cL.prototype={
i(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.db.prototype={
i(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.dK.prototype={
i(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.bH.prototype={}
A.cj.prototype={
i(a){var s,r=this.b
if(r!=null)return r
r=this.a
s=r!==null&&typeof r==="object"?r.stack:null
return this.b=s==null?"":s},
$iay:1}
A.aq.prototype={
i(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.ib(r==null?"unknown":r)+"'"},
$iaM:1,
gbC(){return this},
$C:"$1",
$R:1,
$D:null}
A.cz.prototype={$C:"$0",$R:0}
A.cA.prototype={$C:"$2",$R:2}
A.d9.prototype={}
A.d8.prototype={
i(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.ib(s)+"'"}}
A.bi.prototype={
n(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.bi))return!1
return this.$_target===b.$_target&&this.a===b.a},
gm(a){return(A.i7(this.a)^A.d5(this.$_target))>>>0},
i(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.d6(this.a)+"'")}}
A.d7.prototype={
i(a){return"RuntimeError: "+this.a}}
A.aj.prototype={
gp(a){return this.a},
gB(a){return this.a===0},
gK(){return new A.aO(this,A.F(this).h("aO<1>"))},
bb(a,b){A.F(this).h("m<1,2>").a(b).J(0,new A.dF(this))},
k(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.bk(b)},
bk(a){var s,r,q=this.d
if(q==null)return null
s=q[this.ai(a)]
r=this.aj(s,a)
if(r<0)return null
return s[r].b},
q(a,b,c){var s,r,q=this,p=A.F(q)
p.c.a(b)
p.y[1].a(c)
if(typeof b=="string"){s=q.b
q.ao(s==null?q.b=q.ab():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.ao(r==null?q.c=q.ab():r,b,c)}else q.bm(b,c)},
bm(a,b){var s,r,q,p,o=this,n=A.F(o)
n.c.a(a)
n.y[1].a(b)
s=o.d
if(s==null)s=o.d=o.ab()
r=o.ai(a)
q=s[r]
if(q==null)s[r]=[o.a2(a,b)]
else{p=o.aj(q,a)
if(p>=0)q[p].b=b
else q.push(o.a2(a,b))}},
bs(a,b){if((b&0x3fffffff)===b)return this.b6(this.c,b)
else return this.bl(b)},
bl(a){var s,r,q,p,o=this,n=o.d
if(n==null)return null
s=o.ai(a)
r=n[s]
q=o.aj(r,a)
if(q<0)return null
p=r.splice(q,1)[0]
o.aD(p)
if(r.length===0)delete n[s]
return p.b},
J(a,b){var s,r,q=this
A.F(q).h("~(1,2)").a(b)
s=q.e
r=q.r
while(s!=null){b.$2(s.a,s.b)
if(r!==q.r)throw A.h(A.aJ(q))
s=s.c}},
ao(a,b,c){var s,r=A.F(this)
r.c.a(b)
r.y[1].a(c)
s=a[b]
if(s==null)a[b]=this.a2(b,c)
else s.b=c},
b6(a,b){var s
if(a==null)return null
s=a[b]
if(s==null)return null
this.aD(s)
delete a[b]
return s.b},
aw(){this.r=this.r+1&1073741823},
a2(a,b){var s=this,r=A.F(s),q=new A.dI(r.c.a(a),r.y[1].a(b))
if(s.e==null)s.e=s.f=q
else{r=s.f
r.toString
q.d=r
s.f=r.c=q}++s.a
s.aw()
return q},
aD(a){var s=this,r=a.d,q=a.c
if(r==null)s.e=q
else r.c=q
if(q==null)s.f=r
else q.d=r;--s.a
s.aw()},
ai(a){return J.i(a)&1073741823},
aj(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.d(a[r].a,b))return r
return-1},
i(a){return A.f6(this)},
ab(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$ifM:1}
A.dF.prototype={
$2(a,b){var s=this.a,r=A.F(s)
s.q(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.F(this.a).h("~(1,2)")}}
A.dI.prototype={}
A.aO.prototype={
gp(a){return this.a.a},
gB(a){return this.a.a===0},
gC(a){var s=this.a
return new A.bP(s,s.r,s.e,this.$ti.h("bP<1>"))}}
A.bP.prototype={
gA(){return this.d},
v(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.h(A.aJ(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}},
$iR:1}
A.bN.prototype={
gp(a){return this.a.a},
gB(a){return this.a.a===0},
gC(a){var s=this.a
return new A.bO(s,s.r,s.e,this.$ti.h("bO<1,2>"))}}
A.bO.prototype={
gA(){var s=this.d
s.toString
return s},
v(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.h(A.aJ(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.as(s.a,s.b,r.$ti.h("as<1,2>"))
r.c=s.c
return!0}},
$iR:1}
A.eV.prototype={
$1(a){return this.a(a)},
$S:4}
A.eW.prototype={
$2(a,b){return this.a(a,b)},
$S:9}
A.eX.prototype={
$1(a){return this.a(A.ao(a))},
$S:10}
A.Z.prototype={
i(a){return this.aC(!1)},
aC(a){var s,r,q,p,o,n=this.b1(),m=this.aa(),l=(a?"Record ":"")+"("
for(s=n.length,r="",q=0;q<s;++q,r=", "){l+=r
p=n[q]
if(typeof p=="string")l=l+p+": "
if(!(q<m.length))return A.c(m,q)
o=m[q]
l=a?l+A.h9(o):l+A.e(o)}l+=")"
return l.charCodeAt(0)==0?l:l},
b1(){var s,r=this.$s
while($.ek.length<=r)B.d.u($.ek,null)
s=$.ek[r]
if(s==null){s=this.b_()
B.d.q($.ek,r,s)}return s},
b_(){var s,r,q,p=this.$r,o=p.indexOf("("),n=p.substring(1,o),m=p.substring(o),l=m==="()"?0:m.replace(/[^,]/g,"").length+1,k=t.K,j=J.fH(l,k)
for(s=0;s<l;++s)j[s]=s
if(n!==""){r=n.split(",")
s=r.length
for(q=l;s>0;){--q;--s
B.d.q(j,q,r[s])}}j=A.iV(j,!1,k)
j.$flags=3
return j}}
A.an.prototype={
aa(){return[this.a,this.b]},
n(a,b){if(b==null)return!1
return b instanceof A.an&&this.$s===b.$s&&J.d(this.a,b.a)&&J.d(this.b,b.b)},
gm(a){return A.y(this.$s,this.a,this.b,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)}}
A.b7.prototype={
aa(){return[this.a,this.b,this.c]},
n(a,b){var s=this
if(b==null)return!1
return b instanceof A.b7&&s.$s===b.$s&&J.d(s.a,b.a)&&J.d(s.b,b.b)&&J.d(s.c,b.c)},
gm(a){var s=this
return A.y(s.$s,s.a,s.b,s.c,B.a,B.a,B.a,B.a,B.a,B.a,B.a)}}
A.cK.prototype={
i(a){return"RegExp/"+this.a+"/"+this.b.flags},
gb4(){var s=this,r=s.c
if(r!=null)return r
r=s.b
return s.c=A.fK(s.a,r.multiline,!r.ignoreCase,r.unicode,r.dotAll,"g")},
$idL:1}
A.at.prototype={
gD(a){return B.ao},
aE(a,b,c){return c==null?new Uint8Array(a,b):new Uint8Array(a,b,c)},
$iu:1,
$iat:1}
A.aa.prototype={$iaa:1}
A.bT.prototype={
gae(a){if(((a.$flags|0)&2)!==0)return new A.eq(a.buffer)
else return a.buffer},
b3(a,b,c,d){var s=A.V(b,0,c,d,null)
throw A.h(s)},
ar(a,b,c,d){if(b>>>0!==b||b>c)this.b3(a,b,c,d)}}
A.eq.prototype={
aE(a,b,c){var s=A.fQ(this.a,b,c)
s.$flags=3
return s}}
A.cP.prototype={
gD(a){return B.ap},
$iu:1}
A.N.prototype={
gp(a){return a.length},
$iY:1}
A.bR.prototype={
k(a,b){A.aB(b,a,a.length)
return a[b]},
$il:1,
$if:1,
$in:1}
A.bS.prototype={
q(a,b,c){A.a(c)
a.$flags&2&&A.aE(a)
A.aB(b,a,a.length)
a[b]=c},
aS(a,b,c,d,e){var s,r,q,p
t.bP.a(d)
a.$flags&2&&A.aE(a,5)
s=a.length
this.ar(a,b,s,"start")
this.ar(a,c,s,"end")
if(b>c)A.a1(A.V(b,0,c,null,null))
r=c-b
if(e<0)A.a1(A.aF(e,null))
q=d.length
if(q-e<r)A.a1(A.dS("Not enough elements"))
p=e!==0||q!==r?d.subarray(e,e+r):d
a.set(p,b)
return},
$il:1,
$if:1,
$in:1}
A.bm.prototype={
gD(a){return B.aq},
$iu:1,
$ibm:1}
A.bn.prototype={
gD(a){return B.ar},
$iu:1,
$ibn:1}
A.cQ.prototype={
gD(a){return B.as},
k(a,b){A.aB(b,a,a.length)
return a[b]},
$iu:1}
A.bo.prototype={
gD(a){return B.at},
k(a,b){A.aB(b,a,a.length)
return a[b]},
$iu:1,
$ibo:1}
A.cR.prototype={
gD(a){return B.au},
k(a,b){A.aB(b,a,a.length)
return a[b]},
$iu:1}
A.cS.prototype={
gD(a){return B.aw},
k(a,b){A.aB(b,a,a.length)
return a[b]},
$iu:1}
A.cT.prototype={
gD(a){return B.ax},
k(a,b){A.aB(b,a,a.length)
return a[b]},
$iu:1}
A.bU.prototype={
gD(a){return B.ay},
gp(a){return a.length},
k(a,b){A.aB(b,a,a.length)
return a[b]},
$iu:1}
A.aR.prototype={
gD(a){return B.az},
gp(a){return a.length},
k(a,b){A.aB(b,a,a.length)
return a[b]},
a1(a,b,c){return new Uint8Array(a.subarray(b,A.hD(b,c,a.length)))},
$iu:1,
$iaR:1,
$iac:1}
A.cb.prototype={}
A.cc.prototype={}
A.cd.prototype={}
A.ce.prototype={}
A.a6.prototype={
h(a){return A.co(v.typeUniverse,this,a)},
t(a){return A.ht(v.typeUniverse,this,a)}}
A.dh.prototype={}
A.eo.prototype={
i(a){return A.a_(this.a,null)}}
A.dg.prototype={
i(a){return this.a}}
A.ck.prototype={$ial:1}
A.dY.prototype={
$1(a){var s=this.a,r=s.a
s.a=null
r.$0()},
$S:5}
A.dX.prototype={
$1(a){var s,r
this.a.a=t.M.a(a)
s=this.b
r=this.c
s.firstChild?s.removeChild(r):s.appendChild(r)},
$S:11}
A.dZ.prototype={
$0(){this.a.$0()},
$S:1}
A.e_.prototype={
$0(){this.a.$0()},
$S:1}
A.em.prototype={
aW(a,b){if(self.setTimeout!=null)this.b=self.setTimeout(A.eN(new A.en(this,b),0),a)
else throw A.h(A.dc("`setTimeout()` not found."))},
aG(){if(self.setTimeout!=null){var s=this.b
if(s==null)return
self.clearTimeout(s)
this.b=null}else throw A.h(A.dc("Canceling a timer."))}}
A.en.prototype={
$0(){this.a.b=null
this.b.$0()},
$S:0}
A.dd.prototype={
ah(a){var s,r=this,q=r.$ti
q.h("1/?").a(a)
if(a==null)a=q.c.a(a)
if(!r.b)r.a.a4(a)
else{s=r.a
if(q.h("ah<1>").b(a))s.aq(a)
else s.a7(a)}},
aI(a,b){var s=this.a
if(this.b)s.R(new A.W(a,b))
else s.a5(new A.W(a,b))}}
A.ew.prototype={
$1(a){return this.a.$2(0,a)},
$S:12}
A.ex.prototype={
$2(a,b){this.a.$2(1,new A.bH(a,t.l.a(b)))},
$S:13}
A.eK.prototype={
$2(a,b){this.a(A.a(a),b)},
$S:14}
A.W.prototype={
i(a){return A.e(this.a)},
$ix:1,
gT(){return this.b}}
A.df.prototype={
aI(a,b){var s=this.a
if((s.a&30)!==0)throw A.h(A.dS("Future already completed"))
s.a5(A.jU(a,b))}}
A.c5.prototype={
ah(a){var s,r=this.$ti
r.h("1/?").a(a)
s=this.a
if((s.a&30)!==0)throw A.h(A.dS("Future already completed"))
s.a4(r.h("1/").a(a))},
bc(){return this.ah(null)}}
A.b3.prototype={
bp(a){if((this.c&15)!==6)return!0
return this.b.b.am(t.c0.a(this.d),a.a,t.y,t.K)},
bj(a){var s,r=this,q=r.e,p=null,o=t.z,n=t.K,m=a.a,l=r.b.b
if(t.U.b(q))p=l.bt(q,m,a.b,o,n,t.l)
else p=l.am(t.v.a(q),m,o,n)
try{o=r.$ti.h("2/").a(p)
return o}catch(s){if(t.b7.b(A.af(s))){if((r.c&1)!==0)throw A.h(A.aF("The error handler of Future.then must return a value of the returned future's type","onError"))
throw A.h(A.aF("The error handler of Future.catchError must return a value of the future's type","onError"))}else throw s}}}
A.D.prototype={
an(a,b,c){var s,r,q=this.$ti
q.t(c).h("1/(2)").a(a)
s=$.z
if(s===B.f){if(!t.U.b(b)&&!t.v.b(b))throw A.h(A.dy(b,"onError",u.c))}else{c.h("@<0/>").t(q.c).h("1(2)").a(a)
b=A.kn(b,s)}r=new A.D(s,c.h("D<0>"))
this.a3(new A.b3(r,3,a,b,q.h("@<1>").t(c).h("b3<1,2>")))
return r},
aB(a,b,c){var s,r=this.$ti
r.t(c).h("1/(2)").a(a)
s=new A.D($.z,c.h("D<0>"))
this.a3(new A.b3(s,19,a,b,r.h("@<1>").t(c).h("b3<1,2>")))
return s},
b7(a){this.a=this.a&1|16
this.c=a},
U(a){this.a=a.a&30|this.a&1
this.c=a.c},
a3(a){var s,r=this,q=r.a
if(q<=3){a.a=t.F.a(r.c)
r.c=a}else{if((q&4)!==0){s=t._.a(r.c)
if((s.a&24)===0){s.a3(a)
return}r.U(s)}A.dt(null,null,r.b,t.M.a(new A.e2(r,a)))}},
aA(a){var s,r,q,p,o,n,m=this,l={}
l.a=a
if(a==null)return
s=m.a
if(s<=3){r=t.F.a(m.c)
m.c=a
if(r!=null){q=a.a
for(p=a;q!=null;p=q,q=o)o=q.a
p.a=r}}else{if((s&4)!==0){n=t._.a(m.c)
if((n.a&24)===0){n.aA(a)
return}m.U(n)}l.a=m.X(a)
A.dt(null,null,m.b,t.M.a(new A.e7(l,m)))}},
S(){var s=t.F.a(this.c)
this.c=null
return this.X(s)},
X(a){var s,r,q
for(s=a,r=null;s!=null;r=s,s=q){q=s.a
s.a=r}return r},
a7(a){var s,r=this
r.$ti.c.a(a)
s=r.S()
r.a=8
r.c=a
A.b4(r,s)},
aZ(a){var s,r,q=this
if((a.a&16)!==0){s=q.b===a.b
s=!(s||s)}else s=!1
if(s)return
r=q.S()
q.U(a)
A.b4(q,r)},
R(a){var s=this.S()
this.b7(a)
A.b4(this,s)},
a4(a){var s=this.$ti
s.h("1/").a(a)
if(s.h("ah<1>").b(a)){this.aq(a)
return}this.aY(a)},
aY(a){var s=this
s.$ti.c.a(a)
s.a^=2
A.dt(null,null,s.b,t.M.a(new A.e4(s,a)))},
aq(a){A.e5(this.$ti.h("ah<1>").a(a),this,!1)
return},
a5(a){this.a^=2
A.dt(null,null,this.b,t.M.a(new A.e3(this,a)))},
bv(a,b){var s,r,q=this,p={},o=q.$ti
o.h("1/()?").a(b)
if((q.a&24)!==0){p=new A.D($.z,o)
p.a4(q)
return p}s=$.z
r=new A.D(s,o)
p.a=null
p.a=A.j9(a,new A.ed(q,r,s,o.h("1/()").a(b)))
q.an(new A.ee(p,q,r),new A.ef(p,r),t.P)
return r},
$iah:1}
A.e2.prototype={
$0(){A.b4(this.a,this.b)},
$S:0}
A.e7.prototype={
$0(){A.b4(this.b,this.a.a)},
$S:0}
A.e6.prototype={
$0(){A.e5(this.a.a,this.b,!0)},
$S:0}
A.e4.prototype={
$0(){this.a.a7(this.b)},
$S:0}
A.e3.prototype={
$0(){this.a.R(this.b)},
$S:0}
A.ea.prototype={
$0(){var s,r,q,p,o,n,m,l,k=this,j=null
try{q=k.a.a
j=q.b.b.aN(t.bd.a(q.d),t.z)}catch(p){s=A.af(p)
r=A.bd(p)
if(k.c&&t.n.a(k.b.a.c).a===s){q=k.a
q.c=t.n.a(k.b.a.c)}else{q=s
o=r
if(o==null)o=A.dz(q)
n=k.a
n.c=new A.W(q,o)
q=n}q.b=!0
return}if(j instanceof A.D&&(j.a&24)!==0){if((j.a&16)!==0){q=k.a
q.c=t.n.a(j.c)
q.b=!0}return}if(j instanceof A.D){m=k.b.a
l=new A.D(m.b,m.$ti)
j.an(new A.eb(l,m),new A.ec(l),t.H)
q=k.a
q.c=l
q.b=!1}},
$S:0}
A.eb.prototype={
$1(a){this.a.aZ(this.b)},
$S:5}
A.ec.prototype={
$2(a,b){A.bx(a)
t.l.a(b)
this.a.R(new A.W(a,b))},
$S:6}
A.e9.prototype={
$0(){var s,r,q,p,o,n,m,l
try{q=this.a
p=q.a
o=p.$ti
n=o.c
m=n.a(this.b)
q.c=p.b.b.am(o.h("2/(1)").a(p.d),m,o.h("2/"),n)}catch(l){s=A.af(l)
r=A.bd(l)
q=s
p=r
if(p==null)p=A.dz(q)
o=this.a
o.c=new A.W(q,p)
o.b=!0}},
$S:0}
A.e8.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{s=t.n.a(l.a.a.c)
p=l.b
if(p.a.bp(s)&&p.a.e!=null){p.c=p.a.bj(s)
p.b=!1}}catch(o){r=A.af(o)
q=A.bd(o)
p=t.n.a(l.a.a.c)
if(p.a===r){n=l.b
n.c=p
p=n}else{p=r
n=q
if(n==null)n=A.dz(p)
m=l.b
m.c=new A.W(p,n)
p=m}p.b=!0}},
$S:0}
A.ed.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{q=l.b
p=q.$ti
o=p.h("1/").a(l.c.aN(l.d,l.a.$ti.h("1/")))
if(p.h("ah<1>").b(o))A.e5(o,q,!0)
else{n=q.S()
p.c.a(o)
q.a=8
q.c=o
A.b4(q,n)}}catch(m){s=A.af(m)
r=A.bd(m)
q=s
p=r
if(p==null)p=A.dz(q)
l.b.R(new A.W(q,p))}},
$S:0}
A.ee.prototype={
$1(a){var s
this.b.$ti.c.a(a)
s=this.a.a
if(s.b!=null){s.aG()
this.c.a7(a)}},
$S(){return this.b.$ti.h("G(1)")}}
A.ef.prototype={
$2(a,b){var s
A.bx(a)
t.l.a(b)
s=this.a.a
if(s.b!=null){s.aG()
this.b.R(new A.W(a,b))}},
$S:6}
A.de.prototype={}
A.dm.prototype={}
A.cp.prototype={$ihi:1}
A.dl.prototype={
bu(a){var s,r,q
t.M.a(a)
try{if(B.f===$.z){a.$0()
return}A.hU(null,null,this,a,t.H)}catch(q){s=A.af(q)
r=A.bd(q)
A.fm(A.bx(s),t.l.a(r))}},
aF(a){return new A.el(this,t.M.a(a))},
aN(a,b){b.h("0()").a(a)
if($.z===B.f)return a.$0()
return A.hU(null,null,this,a,b)},
am(a,b,c,d){c.h("@<0>").t(d).h("1(2)").a(a)
d.a(b)
if($.z===B.f)return a.$1(b)
return A.kq(null,null,this,a,b,c,d)},
bt(a,b,c,d,e,f){d.h("@<0>").t(e).t(f).h("1(2,3)").a(a)
e.a(b)
f.a(c)
if($.z===B.f)return a.$2(b,c)
return A.kp(null,null,this,a,b,c,d,e,f)},
aL(a,b,c,d){return b.h("@<0>").t(c).t(d).h("1(2,3)").a(a)}}
A.el.prototype={
$0(){return this.a.bu(this.b)},
$S:0}
A.eJ.prototype={
$0(){A.iI(this.a,this.b)},
$S:0}
A.ca.prototype={
gC(a){var s=this,r=new A.b5(s,s.r,s.$ti.h("b5<1>"))
r.c=s.e
return r},
gp(a){return this.a},
gB(a){return this.a===0},
gM(a){return this.a!==0},
aJ(a,b){var s
if((b&1073741823)===b){s=this.c
if(s==null)return!1
return t.L.a(s[b])!=null}else return this.b0(b)},
b0(a){var s=this.d
if(s==null)return!1
return this.au(s[B.c.gm(a)&1073741823],a)>=0},
u(a,b){var s,r,q=this
q.$ti.c.a(b)
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.ap(s==null?q.b=A.fd():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.ap(r==null?q.c=A.fd():r,b)}else return q.aX(b)},
aX(a){var s,r,q,p=this
p.$ti.c.a(a)
s=p.d
if(s==null)s=p.d=A.fd()
r=J.i(a)&1073741823
q=s[r]
if(q==null)s[r]=[p.ac(a)]
else{if(p.au(q,a)>=0)return!1
q.push(p.ac(a))}return!0},
ap(a,b){this.$ti.c.a(b)
if(t.L.a(a[b])!=null)return!1
a[b]=this.ac(b)
return!0},
ac(a){var s=this,r=new A.dk(s.$ti.c.a(a))
if(s.e==null)s.e=s.f=r
else s.f=s.f.b=r;++s.a
s.r=s.r+1&1073741823
return r},
au(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.d(a[r].a,b))return r
return-1}}
A.dk.prototype={}
A.b5.prototype={
gA(){var s=this.d
return s==null?this.$ti.c.a(s):s},
v(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.h(A.aJ(q))
else if(r==null){s.d=null
return!1}else{s.d=s.$ti.h("1?").a(r.a)
s.c=r.b
return!0}},
$iR:1}
A.p.prototype={
gC(a){return new A.aP(a,this.gp(a),A.be(a).h("aP<p.E>"))},
G(a,b){return this.k(a,b)},
gB(a){return this.gp(a)===0},
gM(a){return!this.gB(a)},
Y(a,b,c){var s=A.be(a)
return new A.r(a,s.t(c).h("1(p.E)").a(b),s.h("@<p.E>").t(c).h("r<1,2>"))},
i(a){return A.f2(a,"[","]")},
$il:1,
$if:1,
$in:1}
A.L.prototype={
af(a,b,c){var s=A.F(this)
return A.fP(this,s.h("L.K"),s.h("L.V"),b,c)},
J(a,b){var s,r,q,p=A.F(this)
p.h("~(L.K,L.V)").a(b)
for(s=this.gK(),s=s.gC(s),p=p.h("L.V");s.v();){r=s.gA()
q=this.k(0,r)
b.$2(r,q==null?p.a(q):q)}},
gp(a){var s=this.gK()
return s.gp(s)},
gB(a){var s=this.gK()
return s.gB(s)},
i(a){return A.f6(this)},
$im:1}
A.dJ.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.e(a)
r.a=(r.a+=s)+": "
s=A.e(b)
r.a+=s},
$S:7}
A.bu.prototype={
gB(a){return this.a===0},
gM(a){return this.a!==0},
i(a){return A.f2(this,"{","}")},
G(a,b){var s,r,q,p=this
A.f9(b,"index")
s=A.jj(p,p.r,p.$ti.c)
for(r=b;s.v();){if(r===0){q=s.d
return q==null?s.$ti.c.a(q):q}--r}throw A.h(A.f1(b,b-r,p,"index"))},
$il:1,
$if:1}
A.ci.prototype={}
A.di.prototype={
k(a,b){var s,r=this.b
if(r==null)return this.c.k(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.b5(b):s}},
gp(a){return this.b==null?this.c.a:this.V().length},
gB(a){return this.gp(0)===0},
gK(){if(this.b==null){var s=this.c
return new A.aO(s,A.F(s).h("aO<1>"))}return new A.dj(this)},
J(a,b){var s,r,q,p,o=this
t.cQ.a(b)
if(o.b==null)return o.c.J(0,b)
s=o.V()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.ey(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.h(A.aJ(o))}},
V(){var s=t.aL.a(this.c)
if(s==null)s=this.c=A.w(Object.keys(this.a),t.s)
return s},
b5(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.ey(this.a[a])
return this.b[a]=s}}
A.dj.prototype={
gp(a){return this.a.gp(0)},
G(a,b){var s=this.a
if(s.b==null)s=s.gK().G(0,b)
else{s=s.V()
if(!(b>=0&&b<s.length))return A.c(s,b)
s=s[b]}return s},
gC(a){var s=this.a
if(s.b==null){s=s.gK()
s=s.gC(s)}else{s=s.V()
s=new J.aG(s,s.length,A.E(s).h("aG<1>"))}return s}}
A.cC.prototype={}
A.cE.prototype={}
A.bM.prototype={
i(a){var s=A.cF(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.cN.prototype={
i(a){return"Cyclic error in JSON stringify"}}
A.cM.prototype={
bf(a,b){var s=A.k7(a,this.gbg().a)
return s},
bh(a,b){var s=A.ji(a,this.gbi().b,null)
return s},
gbi(){return B.J},
gbg(){return B.I}}
A.dH.prototype={}
A.dG.prototype={}
A.ei.prototype={
aP(a){var s,r,q,p,o,n,m=a.length
for(s=this.c,r=0,q=0;q<m;++q){p=a.charCodeAt(q)
if(p>92){if(p>=55296){o=p&64512
if(o===55296){n=q+1
n=!(n<m&&(a.charCodeAt(n)&64512)===56320)}else n=!1
if(!n)if(o===56320){o=q-1
o=!(o>=0&&(a.charCodeAt(o)&64512)===55296)}else o=!1
else o=!0
if(o){if(q>r)s.a+=B.h.L(a,r,q)
r=q+1
o=A.O(92)
s.a+=o
o=A.O(117)
s.a+=o
o=A.O(100)
s.a+=o
o=p>>>8&15
o=A.O(o<10?48+o:87+o)
s.a+=o
o=p>>>4&15
o=A.O(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.O(o<10?48+o:87+o)
s.a+=o}}continue}if(p<32){if(q>r)s.a+=B.h.L(a,r,q)
r=q+1
o=A.O(92)
s.a+=o
switch(p){case 8:o=A.O(98)
s.a+=o
break
case 9:o=A.O(116)
s.a+=o
break
case 10:o=A.O(110)
s.a+=o
break
case 12:o=A.O(102)
s.a+=o
break
case 13:o=A.O(114)
s.a+=o
break
default:o=A.O(117)
s.a+=o
o=A.O(48)
s.a=(s.a+=o)+o
o=p>>>4&15
o=A.O(o<10?48+o:87+o)
s.a+=o
o=p&15
o=A.O(o<10?48+o:87+o)
s.a+=o
break}}else if(p===34||p===92){if(q>r)s.a+=B.h.L(a,r,q)
r=q+1
o=A.O(92)
s.a+=o
o=A.O(p)
s.a+=o}}if(r===0)s.a+=a
else if(r<m)s.a+=B.h.L(a,r,m)},
a6(a){var s,r,q,p
for(s=this.a,r=s.length,q=0;q<r;++q){p=s[q]
if(a==null?p==null:a===p)throw A.h(new A.cN(a,null))}B.d.u(s,a)},
Z(a){var s,r,q,p,o=this
if(o.aO(a))return
o.a6(a)
try{s=o.b.$1(a)
if(!o.aO(s)){q=A.fL(a,null,o.gaz())
throw A.h(q)}q=o.a
if(0>=q.length)return A.c(q,-1)
q.pop()}catch(p){r=A.af(p)
q=A.fL(a,r,o.gaz())
throw A.h(q)}},
aO(a){var s,r,q=this
if(typeof a=="number"){if(!isFinite(a))return!1
q.c.a+=B.b.i(a)
return!0}else if(a===!0){q.c.a+="true"
return!0}else if(a===!1){q.c.a+="false"
return!0}else if(a==null){q.c.a+="null"
return!0}else if(typeof a=="string"){s=q.c
s.a+='"'
q.aP(a)
s.a+='"'
return!0}else if(t.j.b(a)){q.a6(a)
q.bA(a)
s=q.a
if(0>=s.length)return A.c(s,-1)
s.pop()
return!0}else if(t.f.b(a)){q.a6(a)
r=q.bB(a)
s=q.a
if(0>=s.length)return A.c(s,-1)
s.pop()
return r}else return!1},
bA(a){var s,r,q=this.c
q.a+="["
s=J.cu(a)
if(s.gM(a)){this.Z(s.k(a,0))
for(r=1;r<s.gp(a);++r){q.a+=","
this.Z(s.k(a,r))}}q.a+="]"},
bB(a){var s,r,q,p,o,n,m=this,l={}
if(a.gB(a)){m.c.a+="{}"
return!0}s=a.gp(a)*2
r=A.f5(s,null,!1,t.X)
q=l.a=0
l.b=!0
a.J(0,new A.ej(l,r))
if(!l.b)return!1
p=m.c
p.a+="{"
for(o='"';q<s;q+=2,o=',"'){p.a+=o
m.aP(A.ao(r[q]))
p.a+='":'
n=q+1
if(!(n<s))return A.c(r,n)
m.Z(r[n])}p.a+="}"
return!0}}
A.ej.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.d.q(s,r.a++,a)
B.d.q(s,r.a++,b)},
$S:7}
A.eh.prototype={
gaz(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.dV.prototype={
be(a){var s,r,q,p=a.length,o=A.hc(0,null,p)
if(o===0)return new Uint8Array(0)
s=new Uint8Array(o*3)
r=new A.er(s)
if(r.b2(a,0,o)!==o){q=o-1
if(!(q>=0&&q<p))return A.c(a,q)
r.ad()}return B.i.a1(s,0,r.b)}}
A.er.prototype={
ad(){var s,r=this,q=r.c,p=r.b,o=r.b=p+1
q.$flags&2&&A.aE(q)
s=q.length
if(!(p<s))return A.c(q,p)
q[p]=239
p=r.b=o+1
if(!(o<s))return A.c(q,o)
q[o]=191
r.b=p+1
if(!(p<s))return A.c(q,p)
q[p]=189},
ba(a,b){var s,r,q,p,o,n=this
if((b&64512)===56320){s=65536+((a&1023)<<10)|b&1023
r=n.c
q=n.b
p=n.b=q+1
r.$flags&2&&A.aE(r)
o=r.length
if(!(q<o))return A.c(r,q)
r[q]=s>>>18|240
q=n.b=p+1
if(!(p<o))return A.c(r,p)
r[p]=s>>>12&63|128
p=n.b=q+1
if(!(q<o))return A.c(r,q)
r[q]=s>>>6&63|128
n.b=p+1
if(!(p<o))return A.c(r,p)
r[p]=s&63|128
return!0}else{n.ad()
return!1}},
b2(a,b,c){var s,r,q,p,o,n,m,l,k=this
if(b!==c){s=c-1
if(!(s>=0&&s<a.length))return A.c(a,s)
s=(a.charCodeAt(s)&64512)===55296}else s=!1
if(s)--c
for(s=k.c,r=s.$flags|0,q=s.length,p=a.length,o=b;o<c;++o){if(!(o<p))return A.c(a,o)
n=a.charCodeAt(o)
if(n<=127){m=k.b
if(m>=q)break
k.b=m+1
r&2&&A.aE(s)
s[m]=n}else{m=n&64512
if(m===55296){if(k.b+4>q)break
m=o+1
if(!(m<p))return A.c(a,m)
if(k.ba(n,a.charCodeAt(m)))o=m}else if(m===56320){if(k.b+3>q)break
k.ad()}else if(n<=2047){m=k.b
l=m+1
if(l>=q)break
k.b=l
r&2&&A.aE(s)
if(!(m<q))return A.c(s,m)
s[m]=n>>>6|192
k.b=l+1
s[l]=n&63|128}else{m=k.b
if(m+2>=q)break
l=k.b=m+1
r&2&&A.aE(s)
if(!(m<q))return A.c(s,m)
s[m]=n>>>12|224
m=k.b=l+1
if(!(l<q))return A.c(s,l)
s[l]=n>>>6&63|128
k.b=m+1
if(!(m<q))return A.c(s,m)
s[m]=n&63|128}}}return o}}
A.dB.prototype={
$0(){var s=this
return A.a1(A.aF("("+s.a+", "+s.b+", "+s.c+", "+s.d+", "+s.e+", "+s.f+", "+s.r+", "+s.w+")",null))},
$S:8}
A.bF.prototype={
n(a,b){var s
if(b==null)return!1
s=!1
if(b instanceof A.bF)if(this.a===b.a)s=this.b===b.b
return s},
gm(a){return A.y(this.a,this.b,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){var s=this,r=A.fF(A.d4(s)),q=A.ag(A.h7(s)),p=A.ag(A.h3(s)),o=A.ag(A.h4(s)),n=A.ag(A.h6(s)),m=A.ag(A.h8(s)),l=A.dC(A.h5(s)),k=s.b,j=k===0?"":A.dC(k)
return r+"-"+q+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"},
bw(){var s=this,r=A.d4(s)>=-9999&&A.d4(s)<=9999?A.fF(A.d4(s)):A.iG(A.d4(s)),q=A.ag(A.h7(s)),p=A.ag(A.h3(s)),o=A.ag(A.h4(s)),n=A.ag(A.h6(s)),m=A.ag(A.h8(s)),l=A.dC(A.h5(s)),k=s.b,j=k===0?"":A.dC(k)
return r+"-"+q+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"}}
A.aL.prototype={
n(a,b){if(b==null)return!1
return b instanceof A.aL&&this.a===b.a},
gm(a){return B.c.gm(this.a)},
i(a){var s,r,q,p,o,n=this.a,m=B.c.O(n,36e8),l=n%36e8
if(n<0){m=0-m
n=0-l
s="-"}else{n=l
s=""}r=B.c.O(n,6e7)
n%=6e7
q=r<10?"0":""
p=B.c.O(n,1e6)
o=p<10?"0":""
return s+m+":"+q+r+":"+o+p+"."+B.h.aK(B.c.i(n%1e6),6,"0")}}
A.e0.prototype={
i(a){return this.W()}}
A.x.prototype={
gT(){return A.iZ(this)}}
A.cx.prototype={
i(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.cF(s)
return"Assertion failed"}}
A.al.prototype={}
A.a2.prototype={
ga9(){return"Invalid argument"+(!this.a?"(s)":"")},
ga8(){return""},
i(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+A.e(p),n=s.ga9()+q+o
if(!s.a)return n
return n+s.ga8()+": "+A.cF(s.gak())},
gak(){return this.b}}
A.ax.prototype={
gak(){return A.hx(this.b)},
ga9(){return"RangeError"},
ga8(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.e(q):""
else if(q==null)s=": Not greater than or equal to "+A.e(r)
else if(q>r)s=": Not in inclusive range "+A.e(r)+".."+A.e(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.e(r)
return s}}
A.cG.prototype={
gak(){return A.a(this.b)},
ga9(){return"RangeError"},
ga8(){if(A.a(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
$iax:1,
gp(a){return this.f}}
A.c2.prototype={
i(a){return"Unsupported operation: "+this.a}}
A.da.prototype={
i(a){return"UnimplementedError: "+this.a}}
A.c0.prototype={
i(a){return"Bad state: "+this.a}}
A.cD.prototype={
i(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.cF(s)+"."}}
A.cU.prototype={
i(a){return"Out of Memory"},
gT(){return null},
$ix:1}
A.c_.prototype={
i(a){return"Stack Overflow"},
gT(){return null},
$ix:1}
A.e1.prototype={
i(a){return"Exception: "+this.a}}
A.dD.prototype={
i(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException",q=this.b
if(typeof q=="string"){if(q.length>78)q=B.h.L(q,0,75)+"..."
return r+"\n"+q}else return r}}
A.f.prototype={
Y(a,b,c){var s=A.F(this)
return A.iW(this,s.t(c).h("1(f.E)").a(b),s.h("f.E"),c)},
gp(a){var s,r=this.gC(this)
for(s=0;r.v();)++s
return s},
gB(a){return!this.gC(this).v()},
gM(a){return!this.gB(this)},
G(a,b){var s,r
A.f9(b,"index")
s=this.gC(this)
for(r=b;s.v();){if(r===0)return s.gA();--r}throw A.h(A.f1(b,b-r,this,"index"))},
i(a){return A.iO(this,"(",")")}}
A.as.prototype={
i(a){return"MapEntry("+A.e(this.a)+": "+A.e(this.b)+")"}}
A.G.prototype={
gm(a){return A.o.prototype.gm.call(this,0)},
i(a){return"null"}}
A.o.prototype={$io:1,
n(a,b){return this===b},
gm(a){return A.d5(this)},
i(a){return"Instance of '"+A.d6(this)+"'"},
gD(a){return A.l1(this)},
toString(){return this.i(this)}}
A.dn.prototype={
i(a){return""},
$iay:1}
A.b1.prototype={
gp(a){return this.a.length},
i(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$ij7:1}
A.eS.prototype={
$1(a){return t.k.a(a)!=null},
$S:15}
A.et.prototype={
sbq(a){this.a=A.hw(a)},
sbr(a){this.b=t.ak.a(a)}}
A.eZ.prototype={
$1(a){var s,r,q,p,o=A.ev(a).data
if(o==null||!t.m.b(o))return
A.ev(o)
s=A.a(A.eu(o.id))
r=A.ao(o.op)
q=A.ao(o.json)
p=A.ke(o)
A.ez(this.a,new A.dW(s,r,t.f.a(B.p.bf(q,null)).af(0,t.N,t.z),p),this.b)},
$S:16}
A.eA.prototype={
$1(a){var s
A.a(a)
s=this.a.a
s.toString
s=A.kT(s,this.b,a)
return A.q(["pageIndex",s.a,"text",s.b,"hasUnicodeErrors",s.c,"hasTextLayer",s.d],t.N,t.z)},
$S:2}
A.eB.prototype={
$1(a){var s,r,q
A.a(a)
s=this.a.a
s.toString
s=A.kR(s,this.b,a)
r=A.E(s)
q=r.h("r<1,m<j,@>>")
s=A.U(new A.r(s,r.h("m<j,@>(1)").a(A.k8()),q),q.h("B.E"))
return A.q(["pageIndex",a,"annotations",s],t.N,t.z)},
$S:2}
A.eC.prototype={
$1(a){var s,r,q=this
A.a(a)
r=q.a.a
r.toString
s=A.kS(r,q.b,a,q.c)
return A.kN(new A.dQ(a,s),q.d)},
$S:2}
A.eF.prototype={
$0(){var s=this.a
if((s.a.a&30)===0)s.bc()},
$S:1}
A.eG.prototype={
$0(){return A.a1(A.bY("PDFium WASM module failed to initialise within 30 seconds inside the PDFium Worker. Ensure pdfium.js and pdfium.wasm are present at assets/pdfium/ relative to the app origin, alongside pdfium_worker.js (run `make fetch_wasm_assets`)."))},
$S:8}
A.dW.prototype={}
A.J.prototype={}
A.eP.prototype={
$1(a){var s=J.iv(t.bV.a(a),A.hL(),t.cg)
s=A.U(s,s.$ti.h("B.E"))
return s},
$S:17}
A.eQ.prototype={
$1(a){var s,r,q,p
t.az.a(a)
s=this.a
r=a.f
if(r!=null){B.d.u(s,r)
q=s.length-1}else q=null
s=a.c
r=t.N
p=t.z
return A.q(["pageIndex",a.a,"objectIndex",a.b,"metadata",A.q(["width",s.a,"height",s.b,"horizontalDpi",s.c,"verticalDpi",s.d,"bitsPerPixel",s.e,"colorspace",s.f.b,"markedContentId",s.r],r,p),"bounds",A.eR(a.d),"filters",a.e,"bufIndex",q,"bitmapWidth",a.r,"bitmapHeight",a.w],r,p)},
$S:18}
A.eL.prototype={
$1(a){return t.h.a(B.i.gae(t.p.a(a)))},
$S:19}
A.eH.prototype={
$1(a){a.toString
return A.fQ(t.h.a(a),0,null)},
$S:20}
A.cX.prototype={
W(){return"PdfError."+this.b}}
A.cY.prototype={
i(a){return"PdfExtractionException("+this.a.b+")"}}
A.cW.prototype={
i(a){return"PdfDate(raw: "+this.a+", value: "+A.e(this.b)+")"},
n(a,b){var s
if(b==null)return!1
if(this!==b)s=b instanceof A.cW&&this.a===b.a&&J.d(this.b,b.b)
else s=!0
return s},
gm(a){return A.y(this.a,this.b,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)}}
A.dP.prototype={
i(a){var s=this
return"PdfMetadata(title: "+A.e(s.a)+", author: "+A.e(s.b)+", subject: "+A.e(s.c)+", keywords: "+A.e(s.d)+", creator: "+A.e(s.e)+", producer: "+A.e(s.f)+", creationDate: "+A.e(s.r)+", modDate: "+A.e(s.w)+")"}}
A.br.prototype={
i(a){var s=this,r=s.b
if(r.length>40)r=B.h.L(r,0,40)+"\u2026"
return"PdfPageText(pageIndex: "+s.a+", hasTextLayer: "+s.d+", hasUnicodeErrors: "+s.c+", text: "+r+")"},
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.br&&r.a===b.a&&r.b===b.b&&r.c===b.c&&r.d===b.d
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,B.a,B.a,B.a,B.a,B.a,B.a,B.a)}}
A.M.prototype={
W(){return"PdfAnnotationType."+this.b}}
A.cV.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.cV&&r.a===b.a&&r.b===b.b&&r.c===b.c&&r.d===b.d
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){var s=this
return"PdfColor(r: "+s.a+", g: "+s.b+", b: "+s.c+", a: "+s.d+")"}}
A.a5.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.a5&&r.a===b.a&&r.b===b.b&&r.c===b.c&&r.d===b.d
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){var s=this
return"PdfRect(left: "+A.e(s.a)+", bottom: "+A.e(s.b)+", right: "+A.e(s.c)+", top: "+A.e(s.d)+")"}}
A.C.prototype={
n(a,b){var s
if(b==null)return!1
if(this!==b)s=b instanceof A.C&&this.a===b.a&&this.b===b.b
else s=!0
return s},
gm(a){return A.y(this.a,this.b,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){return"PdfPoint(x: "+A.e(this.a)+", y: "+A.e(this.b)+")"}}
A.av.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.av&&r.a.n(0,b.a)&&r.b.n(0,b.b)&&r.c.n(0,b.c)&&r.d.n(0,b.d)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){var s=this
return"PdfQuadPoints(p1: "+s.a.i(0)+", p2: "+s.b.i(0)+", p3: "+s.c.i(0)+", p4: "+s.d.i(0)+")"}}
A.d1.prototype={
n(a,b){var s
if(b==null)return!1
if(this!==b)s=b instanceof A.d1&&J.d(this.a,b.a)&&this.b===b.b
else s=!0
return s},
gm(a){return A.y(this.a,this.b,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){return"PdfPopupAnnotation(rect: "+A.e(this.a)+", flags: "+this.b+")"}}
A.H.prototype={}
A.b_.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.b_&&r.a===b.a&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a,B.a)},
i(a){var s=this
return"PdfTextAnnotation(pageIndex: "+s.a+", contents: "+A.e(s.b)+", author: "+A.e(s.c)+", rect: "+A.e(s.d)+", color: "+A.e(s.e)+", modifiedDate: "+A.e(s.f)+", flags: "+s.r+", popup: "+A.e(s.w)+")"}}
A.aS.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aS&&r.a===b.a&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a,B.a)},
i(a){var s=this
return"PdfFreeTextAnnotation(pageIndex: "+s.a+", contents: "+A.e(s.b)+", author: "+A.e(s.c)+", rect: "+A.e(s.d)+", color: "+A.e(s.e)+", modifiedDate: "+A.e(s.f)+", flags: "+s.r+", popup: "+A.e(s.w)+")"}}
A.aW.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aW&&r.a===b.a&&r.x===b.x&&A.dr(r.y,b.y,t.u)&&r.z==b.z&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,A.bp(s.y),s.z,s.b,s.c,s.d,s.e,s.f,s.r,s.w)},
i(a){var s=this
return"PdfMarkupAnnotation(pageIndex: "+s.a+", subtype: "+s.x.i(0)+", quadPoints: "+s.y.length+" quads, markedText: "+A.e(s.z)+", contents: "+A.e(s.b)+", author: "+A.e(s.c)+", color: "+A.e(s.e)+", flags: "+s.r+")"}}
A.aY.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aY&&r.a===b.a&&r.x===b.x&&J.d(r.y,b.y)&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,s.y,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a)},
i(a){var s=this
return"PdfShapeAnnotation(pageIndex: "+s.a+", subtype: "+s.x.i(0)+", interiorColor: "+A.e(s.y)+", rect: "+A.e(s.d)+", color: "+A.e(s.e)+", flags: "+s.r+")"}}
A.aU.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aU&&r.a===b.a&&r.x.n(0,b.x)&&r.y.n(0,b.y)&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,s.y,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a)},
i(a){var s=this
return"PdfLineAnnotation(pageIndex: "+s.a+", lineStart: "+s.x.i(0)+", lineEnd: "+s.y.i(0)+", color: "+A.e(s.e)+", flags: "+s.r+")"}}
A.aT.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aT&&r.a===b.a&&A.iY(r.x,b.x)&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this,r=s.x,q=A.E(r)
return A.y(s.a,A.bp(new A.r(r,q.h("o?(1)").a(A.kJ()),q.h("r<1,o?>"))),s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a)},
i(a){var s=this
return"PdfInkAnnotation(pageIndex: "+s.a+", strokes: "+s.x.length+", color: "+A.e(s.e)+", flags: "+s.r+")"}}
A.aX.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aX&&r.a===b.a&&r.x===b.x&&A.dr(r.y,b.y,t.w)&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,A.bp(s.y),s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a)},
i(a){var s=this
return"PdfPolygonAnnotation(pageIndex: "+s.a+", subtype: "+s.x.i(0)+", vertices: "+s.y.length+", color: "+A.e(s.e)+", flags: "+s.r+")"}}
A.aV.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aV&&r.a===b.a&&r.x==b.x&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a)},
i(a){var s=this
return"PdfLinkAnnotation(pageIndex: "+s.a+", uri: "+A.e(s.x)+", rect: "+A.e(s.d)+", flags: "+s.r+")"}}
A.aZ.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aZ&&r.a===b.a&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a,B.a)},
i(a){var s=this
return"PdfStampAnnotation(pageIndex: "+s.a+", contents: "+A.e(s.b)+", rect: "+A.e(s.d)+", flags: "+s.r+")"}}
A.b0.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.b0&&r.a===b.a&&r.x===b.x&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a)},
i(a){return"PdfUnknownAnnotation(pageIndex: "+this.a+", rawSubtype: "+this.x+", flags: "+this.r+")"}}
A.aw.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aw&&r.a===b.a&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&A.dr(r.e,b.e,t.b)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,A.bp(s.e),B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){var s=this
return"PdfTocEntry(title: "+s.a+", pageIndex: "+A.e(s.b)+", uri: "+A.e(s.c)+", scrollPosition: "+A.e(s.d)+", children: "+s.e.length+")"}}
A.X.prototype={
W(){return"PdfColorspace."+this.b}}
A.d_.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.d_&&r.a===b.a&&r.b===b.b&&r.c===b.c&&r.d===b.d&&r.e===b.e&&r.f===b.f&&r.r===b.r
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,s.e,s.f,s.r,B.a,B.a,B.a,B.a)},
i(a){var s=this
return"PdfImageMetadata(width: "+s.a+", height: "+s.b+", horizontalDpi: "+A.e(s.c)+", verticalDpi: "+A.e(s.d)+", bitsPerPixel: "+s.e+", colorspace: "+s.f.i(0)+", markedContentId: "+s.r+")"}}
A.au.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.au&&r.a===b.a&&r.b===b.b&&r.c.n(0,b.c)&&r.d.n(0,b.d)&&A.dr(r.e,b.e,t.N)&&r.r==b.r&&r.w==b.w
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,A.bp(s.e),s.r,s.w,B.a,B.a,B.a,B.a)},
i(a){var s=this,r=s.c.i(0),q=s.d.i(0),p=A.e(s.e),o=s.f
o=o!=null?""+o.length+" bytes":"null"
return"PdfImage(pageIndex: "+s.a+", objectIndex: "+s.b+", metadata: "+r+", bounds: "+q+", filters: "+p+", bitmapWidth: "+A.e(s.r)+", bitmapHeight: "+A.e(s.w)+", bgra: "+o+")"}}
A.cZ.prototype={
n(a,b){var s
if(b==null)return!1
if(this!==b)s=b instanceof A.cZ&&this.b===b.b&&this.c===b.c
else s=!0
return s},
gm(a){return A.y(this.b,this.c,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){return"PdfImageBitmap(width: "+this.b+", height: "+this.c+", bgra: "+this.a.length+" bytes)"}}
A.dQ.prototype={
i(a){return"PdfPageImages(pageIndex: "+this.a+", images: "+this.b.length+")"}}
A.bW.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.bW&&r.a===b.a&&r.b===b.b&&r.c===b.c&&A.dr(r.d,b.d,t.O)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,A.bp(s.d),B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){var s=this
return"PdfSearchMatch(pageIndex: "+s.a+", charIndex: "+s.b+", charCount: "+s.c+", rects: "+s.d.length+")"}}
A.d2.prototype={
W(){return"PdfThumbnailSource."+this.b}}
A.bX.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.bX&&r.b===b.b&&r.c===b.c&&r.d===b.d
else s=!0
return s},
gm(a){return A.y(this.b,this.c,this.d,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){var s=this
return"PdfThumbnail(width: "+s.b+", height: "+s.c+", source: "+s.d.i(0)+", bgra: "+s.a.length+" bytes)"}}
A.dM.prototype={
i(a){var s=new A.dN()
return"PdfDocumentInfo(fileVersion: "+A.e(this.a)+", permanentId: "+A.e(s.$1(this.b))+", changingId: "+A.e(s.$1(this.c))+")"}}
A.dN.prototype={
$1(a){var s
if(a==null)s=null
else{s=A.be(a)
s=new A.r(a,s.h("j(p.E)").a(new A.dO()),s.h("r<p.E,j>")).bn(0)}return s},
$S:21}
A.dO.prototype={
$1(a){return B.h.aK(B.c.bx(A.a(a),16),2,"0")},
$S:22}
A.bs.prototype={
i(a){return"PdfiumException: "+this.a}}
A.d0.prototype={
i(a){return"PdfPageSize(widthPt: "+A.e(this.a)+", heightPt: "+A.e(this.b)+")"},
n(a,b){var s
if(b==null)return!1
if(this!==b)s=b instanceof A.d0&&b.a===this.a&&b.b===this.b
else s=!0
return s},
gm(a){return A.y(this.a,this.b,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)}};(function aliases(){var s=J.ar.prototype
s.aV=s.i})();(function installTearOffs(){var s=hunkHelpers._static_1,r=hunkHelpers._static_0
s(A,"kB","je",3)
s(A,"kC","jf",3)
s(A,"kD","jg",3)
r(A,"i_","ku",0)
s(A,"kI","jJ",4)
s(A,"kJ","bp",23)
s(A,"ka","eR",24)
s(A,"hL","kO",25)
s(A,"k9","kP",26)
s(A,"hM","kQ",27)
s(A,"k8","kM",28)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.o,null)
q(A.o,[A.f3,J.cH,A.bZ,J.aG,A.f,A.bC,A.L,A.aq,A.x,A.p,A.dR,A.aP,A.bQ,A.c4,A.T,A.c1,A.Z,A.bE,A.c9,A.dT,A.dK,A.bH,A.cj,A.dI,A.bP,A.bO,A.cK,A.eq,A.a6,A.dh,A.eo,A.em,A.dd,A.W,A.df,A.b3,A.D,A.de,A.dm,A.cp,A.bu,A.dk,A.b5,A.cC,A.cE,A.ei,A.er,A.bF,A.aL,A.e0,A.cU,A.c_,A.e1,A.dD,A.as,A.G,A.dn,A.b1,A.et,A.dW,A.J,A.cY,A.cW,A.dP,A.br,A.cV,A.a5,A.C,A.av,A.d1,A.H,A.aw,A.d_,A.au,A.cZ,A.dQ,A.bW,A.bX,A.dM,A.bs,A.d0])
q(J.cH,[J.cJ,J.bI,J.bL,J.bk,J.bl,J.bK,J.aN])
q(J.bL,[J.ar,J.v,A.at,A.bT])
q(J.ar,[J.d3,J.b2,J.ai])
r(J.cI,A.bZ)
r(J.dE,J.v)
q(J.bK,[J.bj,J.bJ])
q(A.f,[A.az,A.l,A.aQ,A.c3,A.c8])
q(A.az,[A.aH,A.cq])
r(A.c7,A.aH)
r(A.c6,A.cq)
r(A.bD,A.c6)
q(A.L,[A.aI,A.aj,A.di])
q(A.aq,[A.cA,A.cz,A.d9,A.eV,A.eX,A.dY,A.dX,A.ew,A.eb,A.ee,A.eS,A.eZ,A.eA,A.eB,A.eC,A.eP,A.eQ,A.eL,A.eH,A.dN,A.dO])
q(A.cA,[A.dA,A.dF,A.eW,A.ex,A.eK,A.ec,A.ef,A.dJ,A.ej])
q(A.x,[A.cO,A.al,A.cL,A.db,A.d7,A.dg,A.bM,A.cx,A.a2,A.c2,A.da,A.c0,A.cD])
r(A.bv,A.p)
r(A.cB,A.bv)
q(A.l,[A.B,A.aO,A.bN])
r(A.bG,A.aQ)
q(A.B,[A.r,A.dj])
q(A.Z,[A.an,A.b7])
q(A.an,[A.cf,A.bw,A.cg,A.ad])
q(A.b7,[A.ae,A.ch])
r(A.aK,A.bE)
r(A.bV,A.al)
q(A.d9,[A.d8,A.bi])
r(A.aa,A.at)
q(A.bT,[A.cP,A.N])
q(A.N,[A.cb,A.cd])
r(A.cc,A.cb)
r(A.bR,A.cc)
r(A.ce,A.cd)
r(A.bS,A.ce)
q(A.bR,[A.bm,A.bn])
q(A.bS,[A.cQ,A.bo,A.cR,A.cS,A.cT,A.bU,A.aR])
r(A.ck,A.dg)
q(A.cz,[A.dZ,A.e_,A.en,A.e2,A.e7,A.e6,A.e4,A.e3,A.ea,A.e9,A.e8,A.ed,A.el,A.eJ,A.dB,A.eF,A.eG])
r(A.c5,A.df)
r(A.dl,A.cp)
r(A.ci,A.bu)
r(A.ca,A.ci)
r(A.cN,A.bM)
r(A.cM,A.cC)
q(A.cE,[A.dH,A.dG,A.dV])
r(A.eh,A.ei)
q(A.a2,[A.ax,A.cG])
q(A.e0,[A.cX,A.M,A.X,A.d2])
q(A.H,[A.b_,A.aS,A.aW,A.aY,A.aU,A.aT,A.aX,A.aV,A.aZ,A.b0])
s(A.bv,A.c1)
s(A.cq,A.p)
s(A.cb,A.p)
s(A.cc,A.T)
s(A.cd,A.p)
s(A.ce,A.T)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{b:"int",t:"double",bg:"num",j:"String",ba:"bool",G:"Null",n:"List",o:"Object",m:"Map",A:"JSObject"},mangledNames:{},types:["~()","G()","m<j,@>(b)","~(~())","@(@)","G(@)","G(o,ay)","~(o?,o?)","0&()","@(@,j)","@(j)","G(~())","~(@)","G(@,ay)","~(b,@)","ba(H?)","G(A)","n<m<j,@>>(n<C>)","m<j,@>(au)","aa(ac)","ac(o?)","j?(ac?)","j(b)","b(f<o?>)","m<j,@>(a5)","m<j,@>(C)","m<j,@>(av)","m<j,@>(aw)","m<j,@>(H)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;bufPtr,docPtr":(a,b)=>c=>c instanceof A.cf&&a.b(c.a)&&b.b(c.b),"2;end,start":(a,b)=>c=>c instanceof A.bw&&a.b(c.a)&&b.b(c.b),"2;message,transfer":(a,b)=>c=>c instanceof A.cg&&a.b(c.a)&&b.b(c.b),"2;message,type":(a,b)=>c=>c instanceof A.ad&&a.b(c.a)&&b.b(c.b),"3;pageIndex,scrollPosition,uri":(a,b,c)=>d=>d instanceof A.ae&&a.b(d.a)&&b.b(d.b)&&c.b(d.c),"3;pixelHeight,pixelWidth,pixels":(a,b,c)=>d=>d instanceof A.ch&&a.b(d.a)&&b.b(d.b)&&c.b(d.c)}}
A.jx(v.typeUniverse,JSON.parse('{"d3":"ar","b2":"ar","ai":"ar","lk":"at","v":{"n":["1"],"l":["1"],"A":[],"f":["1"]},"cJ":{"ba":[],"u":[]},"bI":{"G":[],"u":[]},"bL":{"A":[]},"ar":{"A":[]},"cI":{"bZ":[]},"dE":{"v":["1"],"n":["1"],"l":["1"],"A":[],"f":["1"]},"aG":{"R":["1"]},"bK":{"t":[],"bg":[]},"bj":{"t":[],"b":[],"bg":[],"u":[]},"bJ":{"t":[],"bg":[],"u":[]},"aN":{"j":[],"dL":[],"u":[]},"az":{"f":["2"]},"bC":{"R":["2"]},"aH":{"az":["1","2"],"f":["2"],"f.E":"2"},"c7":{"aH":["1","2"],"az":["1","2"],"l":["2"],"f":["2"],"f.E":"2"},"c6":{"p":["2"],"n":["2"],"az":["1","2"],"l":["2"],"f":["2"]},"bD":{"c6":["1","2"],"p":["2"],"n":["2"],"az":["1","2"],"l":["2"],"f":["2"],"p.E":"2","f.E":"2"},"aI":{"L":["3","4"],"m":["3","4"],"L.K":"3","L.V":"4"},"cO":{"x":[]},"cB":{"p":["b"],"c1":["b"],"n":["b"],"l":["b"],"f":["b"],"p.E":"b"},"l":{"f":["1"]},"B":{"l":["1"],"f":["1"]},"aP":{"R":["1"]},"aQ":{"f":["2"],"f.E":"2"},"bG":{"aQ":["1","2"],"l":["2"],"f":["2"],"f.E":"2"},"bQ":{"R":["2"]},"r":{"B":["2"],"l":["2"],"f":["2"],"B.E":"2","f.E":"2"},"c3":{"f":["1"],"f.E":"1"},"c4":{"R":["1"]},"bv":{"p":["1"],"c1":["1"],"n":["1"],"l":["1"],"f":["1"]},"cf":{"an":[],"Z":[]},"bw":{"an":[],"Z":[]},"cg":{"an":[],"Z":[]},"ad":{"an":[],"Z":[]},"ae":{"b7":[],"Z":[]},"ch":{"b7":[],"Z":[]},"bE":{"m":["1","2"]},"aK":{"bE":["1","2"],"m":["1","2"]},"c8":{"f":["1"],"f.E":"1"},"c9":{"R":["1"]},"bV":{"al":[],"x":[]},"cL":{"x":[]},"db":{"x":[]},"cj":{"ay":[]},"aq":{"aM":[]},"cz":{"aM":[]},"cA":{"aM":[]},"d9":{"aM":[]},"d8":{"aM":[]},"bi":{"aM":[]},"d7":{"x":[]},"aj":{"L":["1","2"],"fM":["1","2"],"m":["1","2"],"L.K":"1","L.V":"2"},"aO":{"l":["1"],"f":["1"],"f.E":"1"},"bP":{"R":["1"]},"bN":{"l":["as<1,2>"],"f":["as<1,2>"],"f.E":"as<1,2>"},"bO":{"R":["as<1,2>"]},"an":{"Z":[]},"b7":{"Z":[]},"cK":{"dL":[]},"aa":{"at":[],"A":[],"u":[]},"bm":{"p":["t"],"N":["t"],"n":["t"],"Y":["t"],"l":["t"],"A":[],"f":["t"],"T":["t"],"u":[],"p.E":"t"},"bn":{"p":["t"],"N":["t"],"n":["t"],"Y":["t"],"l":["t"],"A":[],"f":["t"],"T":["t"],"u":[],"p.E":"t"},"bo":{"p":["b"],"N":["b"],"n":["b"],"Y":["b"],"l":["b"],"A":[],"f":["b"],"T":["b"],"u":[],"p.E":"b"},"aR":{"ac":[],"p":["b"],"N":["b"],"n":["b"],"Y":["b"],"l":["b"],"A":[],"f":["b"],"T":["b"],"u":[],"p.E":"b"},"at":{"A":[],"u":[]},"bT":{"A":[]},"cP":{"A":[],"u":[]},"N":{"Y":["1"],"A":[]},"bR":{"p":["t"],"N":["t"],"n":["t"],"Y":["t"],"l":["t"],"A":[],"f":["t"],"T":["t"]},"bS":{"p":["b"],"N":["b"],"n":["b"],"Y":["b"],"l":["b"],"A":[],"f":["b"],"T":["b"]},"cQ":{"p":["b"],"N":["b"],"n":["b"],"Y":["b"],"l":["b"],"A":[],"f":["b"],"T":["b"],"u":[],"p.E":"b"},"cR":{"p":["b"],"N":["b"],"n":["b"],"Y":["b"],"l":["b"],"A":[],"f":["b"],"T":["b"],"u":[],"p.E":"b"},"cS":{"p":["b"],"N":["b"],"n":["b"],"Y":["b"],"l":["b"],"A":[],"f":["b"],"T":["b"],"u":[],"p.E":"b"},"cT":{"p":["b"],"N":["b"],"n":["b"],"Y":["b"],"l":["b"],"A":[],"f":["b"],"T":["b"],"u":[],"p.E":"b"},"bU":{"p":["b"],"N":["b"],"n":["b"],"Y":["b"],"l":["b"],"A":[],"f":["b"],"T":["b"],"u":[],"p.E":"b"},"dg":{"x":[]},"ck":{"al":[],"x":[]},"W":{"x":[]},"c5":{"df":["1"]},"D":{"ah":["1"]},"cp":{"hi":[]},"dl":{"cp":[],"hi":[]},"ca":{"ci":["1"],"bu":["1"],"l":["1"],"f":["1"]},"b5":{"R":["1"]},"p":{"n":["1"],"l":["1"],"f":["1"]},"L":{"m":["1","2"]},"bu":{"l":["1"],"f":["1"]},"ci":{"bu":["1"],"l":["1"],"f":["1"]},"di":{"L":["j","@"],"m":["j","@"],"L.K":"j","L.V":"@"},"dj":{"B":["j"],"l":["j"],"f":["j"],"B.E":"j","f.E":"j"},"bM":{"x":[]},"cN":{"x":[]},"cM":{"cC":["o?","j"]},"t":{"bg":[]},"b":{"bg":[]},"n":{"l":["1"],"f":["1"]},"j":{"dL":[]},"cx":{"x":[]},"al":{"x":[]},"a2":{"x":[]},"ax":{"x":[]},"cG":{"ax":[],"x":[]},"c2":{"x":[]},"da":{"x":[]},"c0":{"x":[]},"cD":{"x":[]},"cU":{"x":[]},"c_":{"x":[]},"dn":{"ay":[]},"b1":{"j7":[]},"b_":{"H":[]},"aS":{"H":[]},"aW":{"H":[]},"aY":{"H":[]},"aU":{"H":[]},"aT":{"H":[]},"aX":{"H":[]},"aV":{"H":[]},"aZ":{"H":[]},"b0":{"H":[]},"iN":{"n":["b"],"l":["b"],"f":["b"]},"ac":{"n":["b"],"l":["b"],"f":["b"]},"jc":{"n":["b"],"l":["b"],"f":["b"]},"iL":{"n":["b"],"l":["b"],"f":["b"]},"ja":{"n":["b"],"l":["b"],"f":["b"]},"iM":{"n":["b"],"l":["b"],"f":["b"]},"jb":{"n":["b"],"l":["b"],"f":["b"]},"iJ":{"n":["t"],"l":["t"],"f":["t"]},"iK":{"n":["t"],"l":["t"],"f":["t"]}}'))
A.jw(v.typeUniverse,JSON.parse('{"bv":1,"cq":2,"N":1,"cE":2}'))
var u={c:"Error handler must accept one Object or one Object and a StackTrace as arguments, and return a value of the returned future's type"}
var t=(function rtii(){var s=A.dw
return{n:s("W"),R:s("aK<j,@>"),x:s("aL"),V:s("l<@>"),C:s("x"),Y:s("aM"),r:s("f<@>"),bP:s("f<b>"),J:s("f<o?>"),B:s("v<n<C>>"),bG:s("v<m<j,@>>"),W:s("v<au>"),Q:s("v<C>"),q:s("v<av>"),cN:s("v<a5>"),d:s("v<bW>"),a9:s("v<aw>"),s:s("v<j>"),a:s("v<ac>"),ce:s("v<@>"),t:s("v<b>"),c:s("v<o?>"),T:s("bI"),m:s("A"),g:s("ai"),da:s("Y<@>"),bV:s("n<C>"),j:s("n<@>"),cg:s("m<j,@>"),f:s("m<@,@>"),h:s("aa"),E:s("bm"),bi:s("bn"),A:s("bo"),Z:s("aR"),P:s("G"),K:s("o"),e:s("H"),az:s("au"),w:s("C"),u:s("av"),O:s("a5"),b:s("aw"),G:s("ax"),cY:s("ll"),cD:s("+()"),bq:s("+bufPtr,docPtr(b,b)"),l:s("ay"),N:s("j"),bW:s("u"),b7:s("al"),p:s("ac"),cr:s("b2"),aY:s("c5<~>"),_:s("D<@>"),D:s("D<~>"),y:s("ba"),c0:s("ba(o)"),i:s("t"),z:s("@"),bd:s("@()"),v:s("@(o)"),U:s("@(o,ay)"),S:s("b"),ak:s("ah<A>?"),bc:s("ah<G>?"),aQ:s("A?"),aL:s("n<@>?"),X:s("o?"),k:s("H?"),aD:s("j?"),F:s("b3<@,@>?"),L:s("dk?"),cG:s("ba?"),I:s("t?"),a3:s("b?"),ae:s("bg?"),o:s("bg"),H:s("~"),M:s("~()"),cQ:s("~(j,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.F=J.cH.prototype
B.d=J.v.prototype
B.c=J.bj.prototype
B.b=J.bK.prototype
B.h=J.aN.prototype
B.G=J.ai.prototype
B.H=J.bL.prototype
B.i=A.aR.prototype
B.u=J.d3.prototype
B.m=J.b2.prototype
B.n=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.v=function() {
  var toStringFunction = Object.prototype.toString;
  function getTag(o) {
    var s = toStringFunction.call(o);
    return s.substring(8, s.length - 1);
  }
  function getUnknownTag(object, tag) {
    if (/^HTML[A-Z].*Element$/.test(tag)) {
      var name = toStringFunction.call(object);
      if (name == "[object Object]") return null;
      return "HTMLElement";
    }
  }
  function getUnknownTagGenericBrowser(object, tag) {
    if (object instanceof HTMLElement) return "HTMLElement";
    return getUnknownTag(object, tag);
  }
  function prototypeForTag(tag) {
    if (typeof window == "undefined") return null;
    if (typeof window[tag] == "undefined") return null;
    var constructor = window[tag];
    if (typeof constructor != "function") return null;
    return constructor.prototype;
  }
  function discriminator(tag) { return null; }
  var isBrowser = typeof HTMLElement == "function";
  return {
    getTag: getTag,
    getUnknownTag: isBrowser ? getUnknownTagGenericBrowser : getUnknownTag,
    prototypeForTag: prototypeForTag,
    discriminator: discriminator };
}
B.A=function(getTagFallback) {
  return function(hooks) {
    if (typeof navigator != "object") return hooks;
    var userAgent = navigator.userAgent;
    if (typeof userAgent != "string") return hooks;
    if (userAgent.indexOf("DumpRenderTree") >= 0) return hooks;
    if (userAgent.indexOf("Chrome") >= 0) {
      function confirm(p) {
        return typeof window == "object" && window[p] && window[p].name == p;
      }
      if (confirm("Window") && confirm("HTMLElement")) return hooks;
    }
    hooks.getTag = getTagFallback;
  };
}
B.w=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.z=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Firefox") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "GeoGeolocation": "Geolocation",
    "Location": "!Location",
    "WorkerMessageEvent": "MessageEvent",
    "XMLDocument": "!Document"};
  function getTagFirefox(o) {
    var tag = getTag(o);
    return quickMap[tag] || tag;
  }
  hooks.getTag = getTagFirefox;
}
B.y=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Trident/") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "HTMLDDElement": "HTMLElement",
    "HTMLDTElement": "HTMLElement",
    "HTMLPhraseElement": "HTMLElement",
    "Position": "Geoposition"
  };
  function getTagIE(o) {
    var tag = getTag(o);
    var newTag = quickMap[tag];
    if (newTag) return newTag;
    if (tag == "Object") {
      if (window.DataView && (o instanceof window.DataView)) return "DataView";
    }
    return tag;
  }
  function prototypeForTagIE(tag) {
    var constructor = window[tag];
    if (constructor == null) return null;
    return constructor.prototype;
  }
  hooks.getTag = getTagIE;
  hooks.prototypeForTag = prototypeForTagIE;
}
B.x=function(hooks) {
  var getTag = hooks.getTag;
  var prototypeForTag = hooks.prototypeForTag;
  function getTagFixed(o) {
    var tag = getTag(o);
    if (tag == "Document") {
      if (!!o.xmlVersion) return "!Document";
      return "!HTMLDocument";
    }
    return tag;
  }
  function prototypeForTagFixed(tag) {
    if (tag == "Document") return null;
    return prototypeForTag(tag);
  }
  hooks.getTag = getTagFixed;
  hooks.prototypeForTag = prototypeForTagFixed;
}
B.o=function(hooks) { return hooks; }

B.p=new A.cM()
B.B=new A.cU()
B.a=new A.dR()
B.C=new A.dV()
B.f=new A.dl()
B.D=new A.dn()
B.j=new A.aL(0)
B.E=new A.aL(3e7)
B.I=new A.dG(null)
B.J=new A.dH(null)
B.N=s([],t.B)
B.M=s([],A.dw("v<H>"))
B.K=s([],t.W)
B.q=s([],t.Q)
B.O=s([],t.q)
B.k=s([],t.d)
B.L=s([],t.s)
B.e=s([],t.a)
B.T={thumbnail:0}
B.P=new A.aK(B.T,[null],t.R)
B.S={}
B.r=new A.aK(B.S,[],t.R)
B.R={bitmap:0}
B.Q=new A.aK(B.R,[null],t.R)
B.U=new A.M(0,"text")
B.V=new A.M(1,"link")
B.W=new A.M(10,"squiggly")
B.X=new A.M(11,"strikeout")
B.Y=new A.M(12,"stamp")
B.Z=new A.M(13,"ink")
B.a_=new A.M(14,"popup")
B.a0=new A.M(15,"unknown")
B.a1=new A.M(2,"freeText")
B.a2=new A.M(3,"line")
B.a3=new A.M(4,"square")
B.a4=new A.M(5,"circle")
B.a5=new A.M(6,"polygon")
B.a6=new A.M(7,"polyline")
B.a7=new A.M(8,"highlight")
B.a8=new A.M(9,"underline")
B.t=new A.X(0,"unknown")
B.a9=new A.X(1,"deviceGray")
B.aa=new A.X(10,"indexed")
B.ab=new A.X(11,"pattern")
B.ac=new A.X(2,"deviceRgb")
B.ad=new A.X(3,"deviceCmyk")
B.ae=new A.X(4,"calGray")
B.af=new A.X(5,"calRgb")
B.ag=new A.X(6,"lab")
B.ah=new A.X(7,"iccBased")
B.ai=new A.X(8,"separation")
B.aj=new A.X(9,"deviceN")
B.l=new A.cX(0,"invalidDocument")
B.ak=new A.cX(1,"passwordRequired")
B.al=new A.a5(0,0,0,0)
B.am=new A.d2(0,"embedded")
B.an=new A.d2(1,"rendered")
B.ao=A.a8("lg")
B.ap=A.a8("lh")
B.aq=A.a8("iJ")
B.ar=A.a8("iK")
B.as=A.a8("iL")
B.at=A.a8("iM")
B.au=A.a8("iN")
B.av=A.a8("o")
B.aw=A.a8("ja")
B.ax=A.a8("jb")
B.ay=A.a8("jc")
B.az=A.a8("ac")})();(function staticFields(){$.eg=null
$.a0=A.w([],A.dw("v<o>"))
$.h2=null
$.fB=null
$.fA=null
$.i6=null
$.hZ=null
$.i9=null
$.eO=null
$.eY=null
$.fr=null
$.ek=A.w([],A.dw("v<n<o>?>"))
$.by=null
$.cr=null
$.cs=null
$.fk=!1
$.z=B.f})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"lj","ic",()=>A.i5("_$dart_dartClosure"))
s($,"li","f0",()=>A.i5("_$dart_dartClosure_dartJSInterop"))
s($,"lz","ip",()=>A.w([new J.cI()],A.dw("v<bZ>")))
s($,"ln","id",()=>A.am(A.dU({
toString:function(){return"$receiver$"}})))
s($,"lo","ie",()=>A.am(A.dU({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"lp","ig",()=>A.am(A.dU(null)))
s($,"lq","ih",()=>A.am(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"lt","ik",()=>A.am(A.dU(void 0)))
s($,"lu","il",()=>A.am(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"ls","ij",()=>A.am(A.hf(null)))
s($,"lr","ii",()=>A.am(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"lw","io",()=>A.am(A.hf(void 0)))
s($,"lv","im",()=>A.am(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"lx","fu",()=>A.jd())
s($,"ly","a9",()=>A.i7(B.av))})();(function nativeSupport(){!function(){var s=function(a){var m={}
m[a]=1
return Object.keys(hunkHelpers.convertToFastObject(m))[0]}
v.getIsolateTag=function(a){return s("___dart_"+a+v.isolateTag)}
var r="___dart_isolate_tags_"
var q=Object[r]||(Object[r]=Object.create(null))
var p="_ZxYxX"
for(var o=0;;o++){var n=s(p+"_"+o+"_")
if(!(n in q)){q[n]=1
v.isolateTag=n
break}}v.dispatchPropertyName=v.getIsolateTag("dispatch_record")}()
hunkHelpers.setOrUpdateInterceptorsByTag({SharedArrayBuffer:A.at,ArrayBuffer:A.aa,ArrayBufferView:A.bT,DataView:A.cP,Float32Array:A.bm,Float64Array:A.bn,Int16Array:A.cQ,Int32Array:A.bo,Int8Array:A.cR,Uint16Array:A.cS,Uint32Array:A.cT,Uint8ClampedArray:A.bU,CanvasPixelArray:A.bU,Uint8Array:A.aR})
hunkHelpers.setOrUpdateLeafTags({SharedArrayBuffer:true,ArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.N.$nativeSuperclassTag="ArrayBufferView"
A.cb.$nativeSuperclassTag="ArrayBufferView"
A.cc.$nativeSuperclassTag="ArrayBufferView"
A.bR.$nativeSuperclassTag="ArrayBufferView"
A.cd.$nativeSuperclassTag="ArrayBufferView"
A.ce.$nativeSuperclassTag="ArrayBufferView"
A.bS.$nativeSuperclassTag="ArrayBufferView"})()
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$0=function(){return this()}
Function.prototype.$2$0=function(){return this()}
Function.prototype.$3=function(a,b,c){return this(a,b,c)}
Function.prototype.$4=function(a,b,c,d){return this(a,b,c,d)}
Function.prototype.$1$1=function(a){return this(a)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var s=document.scripts
function onLoad(b){for(var q=0;q<s.length;++q){s[q].removeEventListener("load",onLoad,false)}a(b.target)}for(var r=0;r<s.length;++r){s[r].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var s=A.la
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()
//# sourceMappingURL=pdfium_worker.js.map
