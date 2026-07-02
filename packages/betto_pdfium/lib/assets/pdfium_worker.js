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
if(a[b]!==s){A.lb(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.w(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.fl(b)
return new s(c,this)}:function(){if(s===null)s=A.fl(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.fl(a).prototype
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
fq(a,b,c,d){return{i:a,p:b,e:c,x:d}},
eQ(a){var s,r,q,p,o,n=a[v.dispatchPropertyName]
if(n==null)if($.fo==null){A.l1()
n=a[v.dispatchPropertyName]}if(n!=null){s=n.p
if(!1===s)return n.i
if(!0===s)return a
r=Object.getPrototypeOf(a)
if(s===r)return n.i
if(n.e===r)throw A.f(A.hd("Return interceptor for "+A.e(s(a,n))))}q=a.constructor
if(q==null)p=null
else{o=$.ec
if(o==null)o=$.ec=v.getIsolateTag("_$dart_js")
p=q[o]}if(p!=null)return p
p=A.l6(a)
if(p!=null)return p
if(typeof a=="function")return B.G
s=Object.getPrototypeOf(a)
if(s==null)return B.u
if(s===Object.prototype)return B.u
if(typeof q=="function"){o=$.ec
if(o==null)o=$.ec=v.getIsolateTag("_$dart_js")
Object.defineProperty(q,o,{value:B.m,enumerable:false,writable:true,configurable:true})
return B.m}return B.m},
iM(a,b){if(a<0||a>4294967295)throw A.f(A.V(a,0,4294967295,"length",null))
return J.iN(new Array(a),b)},
fE(a,b){if(a<0)throw A.f(A.aE("Length must be a non-negative integer: "+a,null))
return A.w(new Array(a),b.h("v<0>"))},
iN(a,b){var s=A.w(a,b.h("v<0>"))
s.$flags=1
return s},
fG(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
iP(a,b){var s,r
for(s=a.length;b<s;){r=a.charCodeAt(b)
if(r!==32&&r!==13&&!J.fG(r))break;++b}return b},
iQ(a,b){var s,r,q
for(s=a.length;b>0;b=r){r=b-1
if(!(r<s))return A.c(a,r)
q=a.charCodeAt(r)
if(q!==32&&q!==13&&!J.fG(q))break}return b},
bb(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.bi.prototype
return J.bI.prototype}if(typeof a=="string")return J.aM.prototype
if(a==null)return J.bH.prototype
if(typeof a=="boolean")return J.cG.prototype
if(Array.isArray(a))return J.v.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ai.prototype
if(typeof a=="symbol")return J.bk.prototype
if(typeof a=="bigint")return J.bj.prototype
return a}if(a instanceof A.o)return a
return J.eQ(a)},
cr(a){if(typeof a=="string")return J.aM.prototype
if(a==null)return a
if(Array.isArray(a))return J.v.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ai.prototype
if(typeof a=="symbol")return J.bk.prototype
if(typeof a=="bigint")return J.bj.prototype
return a}if(a instanceof A.o)return a
return J.eQ(a)},
aB(a){if(a==null)return a
if(Array.isArray(a))return J.v.prototype
if(typeof a!="object"){if(typeof a=="function")return J.ai.prototype
if(typeof a=="symbol")return J.bk.prototype
if(typeof a=="bigint")return J.bj.prototype
return a}if(a instanceof A.o)return a
return J.eQ(a)},
kY(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.bi.prototype
return J.bI.prototype}if(a==null)return a
if(!(a instanceof A.o))return J.b1.prototype
return a},
fn(a){if(typeof a=="string")return J.aM.prototype
if(a==null)return a
if(!(a instanceof A.o))return J.b1.prototype
return a},
i1(a){if(a==null)return a
if(typeof a!="object"){if(typeof a=="function")return J.ai.prototype
if(typeof a=="symbol")return J.bk.prototype
if(typeof a=="bigint")return J.bj.prototype
return a}if(a instanceof A.o)return a
return J.eQ(a)},
d(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.bb(a).n(a,b)},
im(a){if(typeof a=="number")return-a
return J.kY(a).aQ(a)},
eY(a,b){if(typeof b==="number")if(Array.isArray(a)||typeof a=="string"||A.l4(a,a[v.dispatchPropertyName]))if(b>>>0===b&&b<a.length)return a[b]
return J.cr(a).l(a,b)},
bg(a,b,c){return J.aB(a).q(a,b,c)},
a4(a,b){return J.aB(a).u(a,b)},
fs(a,b,c){return J.i1(a).aE(a,b,c)},
ft(a,b){return J.aB(a).G(a,b)},
h(a){return J.bb(a).gm(a)},
io(a){return J.cr(a).gB(a)},
ip(a){return J.cr(a).gM(a)},
ct(a){return J.aB(a).gC(a)},
Q(a){return J.cr(a).gp(a)},
iq(a){return J.bb(a).gD(a)},
ir(a,b){return J.aB(a).bo(a,b)},
is(a,b,c){return J.aB(a).Y(a,b,c)},
fu(a,b){return J.fn(a).aT(a,b)},
it(a,b,c){return J.i1(a).a1(a,b,c)},
fv(a,b){return J.fn(a).aU(a,b)},
ap(a){return J.bb(a).i(a)},
iu(a){return J.fn(a).by(a)},
cE:function cE(){},
cG:function cG(){},
bH:function bH(){},
bK:function bK(){},
ar:function ar(){},
d0:function d0(){},
b1:function b1(){},
ai:function ai(){},
bj:function bj(){},
bk:function bk(){},
v:function v(a){this.$ti=a},
cF:function cF(){},
dA:function dA(a){this.$ti=a},
aF:function aF(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
bJ:function bJ(){},
bi:function bi(){},
bI:function bI(){},
aM:function aM(){}},A={f0:function f0(){},
fA(a,b,c){if(t.V.b(a))return new A.c5(a,b.h("@<0>").t(c).h("c5<1,2>"))
return new A.aG(a,b.h("@<0>").t(c).h("aG<1,2>"))},
k(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
ab(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
eI(a,b,c){return a},
fp(a){var s,r
for(s=$.a0.length,r=0;r<s;++r)if(a===$.a0[r])return!0
return!1},
iT(a,b,c,d){if(t.V.b(a))return new A.bF(a,b,c.h("@<0>").t(d).h("bF<1,2>"))
return new A.aP(a,b,c.h("@<0>").t(d).h("aP<1,2>"))},
bv:function bv(){},
bC:function bC(a,b){this.a=a
this.$ti=b},
aG:function aG(a,b){this.a=a
this.$ti=b},
c5:function c5(a,b){this.a=a
this.$ti=b},
aH:function aH(a,b){this.a=a
this.$ti=b},
dw:function dw(a,b){this.a=a
this.b=b},
cL:function cL(a){this.a=a},
cy:function cy(a){this.a=a},
dN:function dN(){},
m:function m(){},
B:function B(){},
aO:function aO(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aP:function aP(a,b,c){this.a=a
this.b=b
this.$ti=c},
bF:function bF(a,b,c){this.a=a
this.b=b
this.$ti=c},
bP:function bP(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
q:function q(a,b,c){this.a=a
this.b=b
this.$ti=c},
c2:function c2(a,b,c){this.a=a
this.b=b
this.$ti=c},
c3:function c3(a,b,c){this.a=a
this.b=b
this.$ti=c},
T:function T(){},
c0:function c0(){},
bu:function bu(){},
i8(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
l4(a,b){var s
if(b!=null){s=b.x
if(s!=null)return s}return t.da.b(a)},
e(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.ap(a)
return s},
d2(a){var s,r=$.h_
if(r==null)r=$.h_=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
iX(a,b){var s,r=/^\s*[+-]?((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$/i.exec(a)
if(r==null)return null
if(3>=r.length)return A.c(r,3)
s=r[3]
if(s!=null)return parseInt(a,10)
if(r[2]!=null)return parseInt(a,16)
return null},
d3(a){var s,r,q,p
if(a instanceof A.o)return A.a_(A.bd(a),null)
s=J.bb(a)
if(s===B.F||s===B.H||t.cr.b(a)){r=B.n(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.a_(A.bd(a),null)},
h6(a){var s,r,q
if(a==null||typeof a=="number"||A.fg(a))return J.ap(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.aq)return a.i(0)
if(a instanceof A.Z)return a.aC(!0)
s=$.il()
for(r=0;r<1;++r){q=s[r].bz(a)
if(q!=null)return q}return"Instance of '"+A.d3(a)+"'"},
fZ(a){var s,r,q,p,o=a.length
if(o<=500)return String.fromCharCode.apply(null,a)
for(s="",r=0;r<o;r=q){q=r+500
p=q<o?q:o
s+=String.fromCharCode.apply(null,a.slice(r,p))}return s},
iY(a){var s,r,q,p=A.w([],t.t)
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.cs)(a),++r){q=a[r]
if(!A.ez(q))throw A.f(A.cq(q))
if(q<=65535)B.d.u(p,q)
else if(q<=1114111){B.d.u(p,55296+(B.c.k(q-65536,10)&1023))
B.d.u(p,56320+(q&1023))}else throw A.f(A.cq(q))}return A.fZ(p)},
h7(a){var s,r,q
for(s=a.length,r=0;r<s;++r){q=a[r]
if(!A.ez(q))throw A.f(A.cq(q))
if(q<0)throw A.f(A.cq(q))
if(q>65535)return A.iY(a)}return A.fZ(a)},
iZ(a,b,c){var s,r,q,p
if(c<=500&&b===0&&c===a.length)return String.fromCharCode.apply(null,a)
for(s=b,r="";s<c;s=q){q=s+500
p=q<c?q:c
r+=String.fromCharCode.apply(null,a.subarray(s,p))}return r},
O(a){var s
if(a<=65535)return String.fromCharCode(a)
if(a<=1114111){s=a-65536
return String.fromCharCode((B.c.k(s,10)|55296)>>>0,s&1023|56320)}throw A.f(A.V(a,0,1114111,null,null))},
j0(a,b,c,d,e,f,g,h,i){var s,r,q,p=b-1
if(0<=a&&a<100){a+=400
p-=4800}s=B.c.a_(h,1000)
r=Date.UTC(a,p,c,d,e,f,g+B.c.N(h-s,1000))
q=!0
if(!isNaN(r))if(!(r<-864e13))if(!(r>864e13))q=r===864e13&&s!==0
if(q)return null
return r},
bs(a){if(a.date===void 0)a.date=new Date(a.a)
return a.date},
d1(a){var s=A.bs(a).getUTCFullYear()+0
return s},
h4(a){var s=A.bs(a).getUTCMonth()+1
return s},
h0(a){var s=A.bs(a).getUTCDate()+0
return s},
h1(a){var s=A.bs(a).getUTCHours()+0
return s},
h3(a){var s=A.bs(a).getUTCMinutes()+0
return s},
h5(a){var s=A.bs(a).getUTCSeconds()+0
return s},
h2(a){var s=A.bs(a).getUTCMilliseconds()+0
return s},
iW(a){var s=a.$thrownJsError
if(s==null)return null
return A.bc(s)},
j_(a,b){var s
if(a.$thrownJsError==null){s=new Error()
A.K(a,s)
a.$thrownJsError=s
s.stack=b.i(0)}},
S(a){throw A.f(A.cq(a))},
c(a,b){if(a==null)J.Q(a)
throw A.f(A.ds(a,b))},
ds(a,b){var s,r="index"
if(!A.ez(b))return new A.a2(!0,b,r,null)
s=J.Q(a)
if(b<0||b>=s)return A.eZ(b,s,a,r)
return A.h8(b,r)},
kI(a,b,c){if(a<0||a>c)return A.V(a,0,c,"start",null)
if(b!=null)if(b<a||b>c)return A.V(b,a,c,"end",null)
return new A.a2(!0,b,"end",null)},
cq(a){return new A.a2(!0,a,null,null)},
f(a){return A.K(a,new Error())},
K(a,b){var s
if(a==null)a=new A.al()
b.dartException=a
s=A.lc
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
lc(){return J.ap(this.dartException)},
a1(a,b){throw A.K(a,b==null?new Error():b)},
aD(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.a1(A.jH(a,b,c),s)},
jH(a,b,c){var s,r,q,p,o,n,m,l,k
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
return new A.c1("'"+s+"': Cannot "+o+" "+l+k+n)},
cs(a){throw A.f(A.aI(a))},
am(a){var s,r,q,p,o,n
a=A.l9(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.w([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.dP(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
dQ(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
hc(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
f1(a,b){var s=b==null,r=s?null:b.method
return new A.cI(a,r,s?null:b.receiver)},
af(a){var s
if(a==null)return new A.dG(a)
if(a instanceof A.bG){s=a.a
return A.aC(a,s==null?A.bx(s):s)}if(typeof a!=="object")return a
if("dartException" in a)return A.aC(a,a.dartException)
return A.kw(a)},
aC(a,b){if(t.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
kw(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.c.k(r,16)&8191)===10)switch(q){case 438:return A.aC(a,A.f1(A.e(s)+" (Error "+q+")",null))
case 445:case 5007:A.e(s)
return A.aC(a,new A.bU())}}if(a instanceof TypeError){p=$.ia()
o=$.ib()
n=$.ic()
m=$.id()
l=$.ih()
k=$.ii()
j=$.ig()
$.ie()
i=$.ik()
h=$.ij()
g=p.H(s)
if(g!=null)return A.aC(a,A.f1(A.ao(s),g))
else{g=o.H(s)
if(g!=null){g.method="call"
return A.aC(a,A.f1(A.ao(s),g))}else if(n.H(s)!=null||m.H(s)!=null||l.H(s)!=null||k.H(s)!=null||j.H(s)!=null||m.H(s)!=null||i.H(s)!=null||h.H(s)!=null){A.ao(s)
return A.aC(a,new A.bU())}}return A.aC(a,new A.d8(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.bZ()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.aC(a,new A.a2(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.bZ()
return a},
bc(a){var s
if(a instanceof A.bG)return a.b
if(a==null)return new A.ch(a)
s=a.$cachedTrace
if(s!=null)return s
s=new A.ch(a)
if(typeof a==="object")a.$cachedTrace=s
return s},
i4(a){if(a==null)return J.h(a)
if(typeof a=="object")return A.d2(a)
return J.h(a)},
kX(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.q(0,a[s],a[r])}return b},
jS(a,b,c,d,e,f){t.Y.a(a)
switch(A.a(b)){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.f(new A.dY("Unsupported number of arguments for wrapped closure"))},
eJ(a,b){var s=a.$identity
if(!!s)return s
s=A.kE(a,b)
a.$identity=s
return s},
kE(a,b){var s
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
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.jS)},
iB(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.d5().constructor.prototype):Object.create(new A.bh(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.fB(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.ix(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.fB(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
ix(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.f("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.iv)}throw A.f("Error in functionType of tearoff")},
iy(a,b,c,d){var s=A.fz
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
fB(a,b,c,d){if(c)return A.iA(a,b,d)
return A.iy(b.length,d,a,b)},
iz(a,b,c,d){var s=A.fz,r=A.iw
switch(b?-1:a){case 0:throw A.f(new A.d4("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
iA(a,b,c){var s,r
if($.fx==null)$.fx=A.fw("interceptor")
if($.fy==null)$.fy=A.fw("receiver")
s=b.length
r=A.iz(s,c,a,b)
return r},
fl(a){return A.iB(a)},
iv(a,b){return A.cm(v.typeUniverse,A.bd(a.a),b)},
fz(a){return a.a},
iw(a){return a.b},
fw(a){var s,r,q,p=new A.bh("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.f(A.aE("Field name "+a+" not found.",null))},
i2(a){return v.getIsolateTag(a)},
lx(a,b,c){Object.defineProperty(a,b,{value:c,enumerable:false,writable:true,configurable:true})},
l6(a){var s,r,q,p,o,n=A.ao($.i3.$1(a)),m=$.eK[n]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.eU[n]
if(s!=null)return s
r=v.interceptorsByTag[n]
if(r==null){q=A.hv($.hW.$2(a,n))
if(q!=null){m=$.eK[q]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.eU[q]
if(s!=null)return s
r=v.interceptorsByTag[q]
n=q}}if(r==null)return null
s=r.prototype
p=n[0]
if(p==="!"){m=A.eW(s)
$.eK[n]=m
Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}if(p==="~"){$.eU[n]=s
return s}if(p==="-"){o=A.eW(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}if(p==="+")return A.i5(a,s)
if(p==="*")throw A.f(A.hd(n))
if(v.leafTags[n]===true){o=A.eW(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}else return A.i5(a,s)},
i5(a,b){var s=Object.getPrototypeOf(a)
Object.defineProperty(s,v.dispatchPropertyName,{value:J.fq(b,s,null,null),enumerable:false,writable:true,configurable:true})
return b},
eW(a){return J.fq(a,!1,null,!!a.$iY)},
l8(a,b,c){var s=b.prototype
if(v.leafTags[a]===true)return A.eW(s)
else return J.fq(s,c,null,null)},
l1(){if(!0===$.fo)return
$.fo=!0
A.l2()},
l2(){var s,r,q,p,o,n,m,l
$.eK=Object.create(null)
$.eU=Object.create(null)
A.l0()
s=v.interceptorsByTag
r=Object.getOwnPropertyNames(s)
if(typeof window!="undefined"){window
q=function(){}
for(p=0;p<r.length;++p){o=r[p]
n=$.i6.$1(o)
if(n!=null){m=A.l8(o,s[o],n)
if(m!=null){Object.defineProperty(n,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
q.prototype=n}}}}for(p=0;p<r.length;++p){o=r[p]
if(/^[A-Za-z_]/.test(o)){l=s[o]
s["!"+o]=l
s["~"+o]=l
s["-"+o]=l
s["+"+o]=l
s["*"+o]=l}}},
l0(){var s,r,q,p,o,n,m=B.v()
m=A.bA(B.w,A.bA(B.x,A.bA(B.o,A.bA(B.o,A.bA(B.y,A.bA(B.z,A.bA(B.A(B.n),m)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){s=dartNativeDispatchHooksTransformer
if(typeof s=="function")s=[s]
if(Array.isArray(s))for(r=0;r<s.length;++r){q=s[r]
if(typeof q=="function")m=q(m)||m}}p=m.getTag
o=m.getUnknownTag
n=m.prototypeForTag
$.i3=new A.eR(p)
$.hW=new A.eS(o)
$.i6=new A.eT(n)},
bA(a,b){return a(b)||b},
kH(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
fH(a,b,c,d,e,f){var s=b?"m":"",r=c?"":"i",q=d?"u":"",p=e?"s":"",o=function(g,h){try{return new RegExp(g,h)}catch(n){return n}}(a,s+r+q+p+f)
if(o instanceof RegExp)return o
throw A.f(A.fD("Illegal RegExp pattern ("+String(o)+")",a))},
kV(a){if(a.indexOf("$",0)>=0)return a.replace(/\$/g,"$$$$")
return a},
l9(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
la(a,b,c){var s,r=b.gb4()
r.lastIndex=0
s=a.replace(r,A.kV(c))
return s},
cd:function cd(a,b){this.a=a
this.b=b},
bw:function bw(a,b){this.a=a
this.b=b},
ce:function ce(a,b){this.a=a
this.b=b},
ad:function ad(a,b){this.a=a
this.b=b},
ae:function ae(a,b,c){this.a=a
this.b=b
this.c=c},
cf:function cf(a,b,c){this.a=a
this.b=b
this.c=c},
bD:function bD(){},
aJ:function aJ(a,b,c){this.a=a
this.b=b
this.$ti=c},
c6:function c6(a,b){this.a=a
this.$ti=b},
c7:function c7(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
bY:function bY(){},
dP:function dP(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
bU:function bU(){},
cI:function cI(a,b,c){this.a=a
this.b=b
this.c=c},
d8:function d8(a){this.a=a},
dG:function dG(a){this.a=a},
bG:function bG(a,b){this.a=a
this.b=b},
ch:function ch(a){this.a=a
this.b=null},
aq:function aq(){},
cw:function cw(){},
cx:function cx(){},
d6:function d6(){},
d5:function d5(){},
bh:function bh(a,b){this.a=a
this.b=b},
d4:function d4(a){this.a=a},
aj:function aj(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
dB:function dB(a){this.a=a},
dE:function dE(a,b){var _=this
_.a=a
_.b=b
_.d=_.c=null},
aN:function aN(a,b){this.a=a
this.$ti=b},
bO:function bO(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
bM:function bM(a,b){this.a=a
this.$ti=b},
bN:function bN(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
eR:function eR(a){this.a=a},
eS:function eS(a){this.a=a},
eT:function eT(a){this.a=a},
Z:function Z(){},
an:function an(){},
b6:function b6(){},
cH:function cH(a,b){var _=this
_.a=a
_.b=b
_.e=_.d=_.c=null},
hB(a){return a},
fN(a,b,c){return c==null?new Uint8Array(a,b):new Uint8Array(a,b,c)},
aA(a,b,c){if(a>>>0!==a||a>=c)throw A.f(A.ds(b,a))},
hA(a,b,c){var s
if(!(a>>>0!==a))s=b>>>0!==b||a>b||b>c
else s=!0
if(s)throw A.f(A.kI(a,b,c))
return b},
at:function at(){},
aa:function aa(){},
bS:function bS(){},
em:function em(a){this.a=a},
cM:function cM(){},
N:function N(){},
bQ:function bQ(){},
bR:function bR(){},
bl:function bl(){},
bm:function bm(){},
cN:function cN(){},
bn:function bn(){},
cO:function cO(){},
cP:function cP(){},
cQ:function cQ(){},
bT:function bT(){},
aQ:function aQ(){},
c9:function c9(){},
ca:function ca(){},
cb:function cb(){},
cc:function cc(){},
f7(a,b){var s=b.c
return s==null?b.c=A.ck(a,"ah",[b.x]):s},
ha(a){var s=a.w
if(s===6||s===7)return A.ha(a.x)
return s===11||s===12},
j2(a){return a.as},
dt(a){return A.el(v.typeUniverse,a,!1)},
b8(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.b8(a1,s,a3,a4)
if(r===s)return a2
return A.ho(a1,r,!0)
case 7:s=a2.x
r=A.b8(a1,s,a3,a4)
if(r===s)return a2
return A.hn(a1,r,!0)
case 8:q=a2.y
p=A.bz(a1,q,a3,a4)
if(p===q)return a2
return A.ck(a1,a2.x,p)
case 9:o=a2.x
n=A.b8(a1,o,a3,a4)
m=a2.y
l=A.bz(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.fb(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.bz(a1,j,a3,a4)
if(i===j)return a2
return A.hp(a1,k,i)
case 11:h=a2.x
g=A.b8(a1,h,a3,a4)
f=a2.y
e=A.kt(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.hm(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.bz(a1,d,a3,a4)
o=a2.x
n=A.b8(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.fc(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.f(A.cv("Attempted to substitute unexpected RTI kind "+a0))}},
bz(a,b,c,d){var s,r,q,p,o=b.length,n=A.eo(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.b8(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
ku(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.eo(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.b8(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
kt(a,b,c,d){var s,r=b.a,q=A.bz(a,r,c,d),p=b.b,o=A.bz(a,p,c,d),n=b.c,m=A.ku(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.de()
s.a=q
s.b=o
s.c=m
return s},
w(a,b){a[v.arrayRti]=b
return a},
hY(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.l_(s)
return a.$S()}return null},
l3(a,b){var s
if(A.ha(b))if(a instanceof A.aq){s=A.hY(a)
if(s!=null)return s}return A.bd(a)},
bd(a){if(a instanceof A.o)return A.E(a)
if(Array.isArray(a))return A.H(a)
return A.ff(J.bb(a))},
H(a){var s=a[v.arrayRti],r=t.ce
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
E(a){var s=a.$ti
return s!=null?s:A.ff(a)},
ff(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.jP(a,s)},
jP(a,b){var s=a instanceof A.aq?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.jv(v.typeUniverse,s.name)
b.$ccache=r
return r},
l_(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.el(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
kZ(a){return A.ba(A.E(a))},
fk(a){var s
if(a instanceof A.Z)return A.kW(a.$r,a.aa())
s=a instanceof A.aq?A.hY(a):null
if(s!=null)return s
if(t.bW.b(a))return J.iq(a).a
if(Array.isArray(a))return A.H(a)
return A.bd(a)},
ba(a){var s=a.r
return s==null?a.r=new A.ek(a):s},
kW(a,b){var s,r,q=b,p=q.length
if(p===0)return t.cD
if(0>=p)return A.c(q,0)
s=A.cm(v.typeUniverse,A.fk(q[0]),"@<0>")
for(r=1;r<p;++r){if(!(r<q.length))return A.c(q,r)
s=A.hq(v.typeUniverse,s,A.fk(q[r]))}return A.cm(v.typeUniverse,s,a)},
a8(a){return A.ba(A.el(v.typeUniverse,a,!1))},
jO(a){var s=this
s.b=A.kq(s)
return s.b(a)},
kq(a){var s,r,q,p,o
if(a===t.K)return A.jY
if(A.be(a))return A.k1
s=a.w
if(s===6)return A.jL
if(s===1)return A.hG
if(s===7)return A.jT
r=A.kp(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.be)){a.f="$i"+q
if(q==="n")return A.jW
if(a===t.m)return A.jV
return A.k0}}else if(s===10){p=A.kH(a.x,a.y)
o=p==null?A.hG:p
return o==null?A.bx(o):o}return A.jJ},
kp(a){if(a.w===8){if(a===t.S)return A.ez
if(a===t.i||a===t.o)return A.jX
if(a===t.N)return A.k_
if(a===t.y)return A.fg}return null},
jN(a){var s=this,r=A.jI
if(A.be(s))r=A.jA
else if(s===t.K)r=A.bx
else if(A.bB(s)){r=A.jK
if(s===t.a3)r=A.dm
else if(s===t.aD)r=A.hv
else if(s===t.cG)r=A.jx
else if(s===t.ae)r=A.hu
else if(s===t.I)r=A.jy
else if(s===t.aQ)r=A.ht}else if(s===t.S)r=A.a
else if(s===t.N)r=A.ao
else if(s===t.y)r=A.dl
else if(s===t.o)r=A.jz
else if(s===t.i)r=A.eq
else if(s===t.m)r=A.er
s.a=r
return s.a(a)},
jJ(a){var s=this
if(a==null)return A.bB(s)
return A.l5(v.typeUniverse,A.l3(a,s),s)},
jL(a){if(a==null)return!0
return this.x.b(a)},
k0(a){var s,r=this
if(a==null)return A.bB(r)
s=r.f
if(a instanceof A.o)return!!a[s]
return!!J.bb(a)[s]},
jW(a){var s,r=this
if(a==null)return A.bB(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.o)return!!a[s]
return!!J.bb(a)[s]},
jV(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.o)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
hF(a){if(typeof a=="object"){if(a instanceof A.o)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
jI(a){var s=this
if(a==null){if(A.bB(s))return a}else if(s.b(a))return a
throw A.K(A.hC(a,s),new Error())},
jK(a){var s=this
if(a==null||s.b(a))return a
throw A.K(A.hC(a,s),new Error())},
hC(a,b){return new A.ci("TypeError: "+A.hg(a,A.a_(b,null)))},
hg(a,b){return A.cC(a)+": type '"+A.a_(A.fk(a),null)+"' is not a subtype of type '"+b+"'"},
a3(a,b){return new A.ci("TypeError: "+A.hg(a,b))},
jT(a){var s=this
return s.x.b(a)||A.f7(v.typeUniverse,s).b(a)},
jY(a){return a!=null},
bx(a){if(a!=null)return a
throw A.K(A.a3(a,"Object"),new Error())},
k1(a){return!0},
jA(a){return a},
hG(a){return!1},
fg(a){return!0===a||!1===a},
dl(a){if(!0===a)return!0
if(!1===a)return!1
throw A.K(A.a3(a,"bool"),new Error())},
jx(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.K(A.a3(a,"bool?"),new Error())},
eq(a){if(typeof a=="number")return a
throw A.K(A.a3(a,"double"),new Error())},
jy(a){if(typeof a=="number")return a
if(a==null)return a
throw A.K(A.a3(a,"double?"),new Error())},
ez(a){return typeof a=="number"&&Math.floor(a)===a},
a(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.K(A.a3(a,"int"),new Error())},
dm(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.K(A.a3(a,"int?"),new Error())},
jX(a){return typeof a=="number"},
jz(a){if(typeof a=="number")return a
throw A.K(A.a3(a,"num"),new Error())},
hu(a){if(typeof a=="number")return a
if(a==null)return a
throw A.K(A.a3(a,"num?"),new Error())},
k_(a){return typeof a=="string"},
ao(a){if(typeof a=="string")return a
throw A.K(A.a3(a,"String"),new Error())},
hv(a){if(typeof a=="string")return a
if(a==null)return a
throw A.K(A.a3(a,"String?"),new Error())},
er(a){if(A.hF(a))return a
throw A.K(A.a3(a,"JSObject"),new Error())},
ht(a){if(a==null)return a
if(A.hF(a))return a
throw A.K(A.a3(a,"JSObject?"),new Error())},
hS(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.a_(a[q],b)
return s},
kj(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.hS(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.a_(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
hD(a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=", ",a2=null
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
if(l===8){p=A.kv(a.x)
o=a.y
return o.length>0?p+("<"+A.hS(o,b)+">"):p}if(l===10)return A.kj(a,b)
if(l===11)return A.hD(a,b,null)
if(l===12)return A.hD(a.x,b,a.y)
if(l===13){n=a.x
m=b.length
n=m-1-n
if(!(n>=0&&n<m))return A.c(b,n)
return b[n]}return"?"},
kv(a){var s=v.mangledGlobalNames[a]
if(s!=null)return s
return"minified:"+a},
jw(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
jv(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.el(a,b,!1)
else if(typeof m=="number"){s=m
r=A.cl(a,5,"#")
q=A.eo(s)
for(p=0;p<s;++p)q[p]=r
o=A.ck(a,b,q)
n[b]=o
return o}else return m},
ju(a,b){return A.hr(a.tR,b)},
jt(a,b){return A.hr(a.eT,b)},
el(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.hk(A.hi(a,null,b,!1))
r.set(b,s)
return s},
cm(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.hk(A.hi(a,b,c,!0))
q.set(c,r)
return r},
hq(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.fb(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
az(a,b){b.a=A.jN
b.b=A.jO
return b},
cl(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.a6(null,null)
s.w=b
s.as=c
r=A.az(a,s)
a.eC.set(c,r)
return r},
ho(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.jr(a,b,r,c)
a.eC.set(r,s)
return s},
jr(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.be(b))if(!(b===t.P||b===t.T))if(s!==6)r=s===7&&A.bB(b.x)
if(r)return b
else if(s===1)return t.P}q=new A.a6(null,null)
q.w=6
q.x=b
q.as=c
return A.az(a,q)},
hn(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.jp(a,b,r,c)
a.eC.set(r,s)
return s},
jp(a,b,c,d){var s,r
if(d){s=b.w
if(A.be(b)||b===t.K)return b
else if(s===1)return A.ck(a,"ah",[b])
else if(b===t.P||b===t.T)return t.bc}r=new A.a6(null,null)
r.w=7
r.x=b
r.as=c
return A.az(a,r)},
js(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.a6(null,null)
s.w=13
s.x=b
s.as=q
r=A.az(a,s)
a.eC.set(q,r)
return r},
cj(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
jo(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
ck(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.cj(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.a6(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.az(a,r)
a.eC.set(p,q)
return q},
fb(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.cj(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.a6(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.az(a,o)
a.eC.set(q,n)
return n},
hp(a,b,c){var s,r,q="+"+(b+"("+A.cj(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.a6(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.az(a,s)
a.eC.set(q,r)
return r},
hm(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.cj(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.cj(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.jo(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.a6(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.az(a,p)
a.eC.set(r,o)
return o},
fc(a,b,c,d){var s,r=b.as+("<"+A.cj(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.jq(a,b,c,r,d)
a.eC.set(r,s)
return s},
jq(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.eo(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.b8(a,b,r,0)
m=A.bz(a,c,r,0)
return A.fc(a,n,m,c!==m)}}l=new A.a6(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.az(a,l)},
hi(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
hk(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.ji(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.hj(a,r,l,k,!1)
else if(q===46)r=A.hj(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.b5(a.u,a.e,k.pop()))
break
case 94:k.push(A.js(a.u,k.pop()))
break
case 35:k.push(A.cl(a.u,5,"#"))
break
case 64:k.push(A.cl(a.u,2,"@"))
break
case 126:k.push(A.cl(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.jk(a,k)
break
case 38:A.jj(a,k)
break
case 63:p=a.u
k.push(A.ho(p,A.b5(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.hn(p,A.b5(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.jh(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.hl(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.jm(a.u,a.e,o)
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
return A.b5(a.u,a.e,m)},
ji(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
hj(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.jw(s,o.x)[p]
if(n==null)A.a1('No "'+p+'" in "'+A.j2(o)+'"')
d.push(A.cm(s,o,n))}else d.push(p)
return m},
jk(a,b){var s,r=a.u,q=A.hh(a,b),p=b.pop()
if(typeof p=="string")b.push(A.ck(r,p,q))
else{s=A.b5(r,a.e,p)
switch(s.w){case 11:b.push(A.fc(r,s,q,a.n))
break
default:b.push(A.fb(r,s,q))
break}}},
jh(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.hh(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.b5(p,a.e,o)
q=new A.de()
q.a=s
q.b=n
q.c=m
b.push(A.hm(p,r,q))
return
case-4:b.push(A.hp(p,b.pop(),s))
return
default:throw A.f(A.cv("Unexpected state under `()`: "+A.e(o)))}},
jj(a,b){var s=b.pop()
if(0===s){b.push(A.cl(a.u,1,"0&"))
return}if(1===s){b.push(A.cl(a.u,4,"1&"))
return}throw A.f(A.cv("Unexpected extended operation "+A.e(s)))},
hh(a,b){var s=b.splice(a.p)
A.hl(a.u,a.e,s)
a.p=b.pop()
return s},
b5(a,b,c){if(typeof c=="string")return A.ck(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.jl(a,b,c)}else return c},
hl(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.b5(a,b,c[s])},
jm(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.b5(a,b,c[s])},
jl(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.f(A.cv("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.f(A.cv("Bad index "+c+" for "+b.i(0)))},
l5(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.I(a,b,null,c,null)
r.set(c,s)}return s},
I(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.be(d))return!0
s=b.w
if(s===4)return!0
if(A.be(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.I(a,c[b.x],c,d,e))return!0
q=d.w
p=t.P
if(b===p||b===t.T){if(q===7)return A.I(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.K){if(s===7)return A.I(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.I(a,b.x,c,d,e))return!1
return A.I(a,A.f7(a,b),c,d,e)}if(s===6)return A.I(a,p,c,d,e)&&A.I(a,b.x,c,d,e)
if(q===7){if(A.I(a,b,c,d.x,e))return!0
return A.I(a,b,c,A.f7(a,d),e)}if(q===6)return A.I(a,b,c,p,e)||A.I(a,b,c,d.x,e)
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
if(!A.I(a,j,c,i,e)||!A.I(a,i,e,j,c))return!1}return A.hE(a,b.x,c,d.x,e)}if(q===11){if(b===t.g)return!0
if(p)return!1
return A.hE(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.jU(a,b,c,d,e)}if(o&&q===10)return A.jZ(a,b,c,d,e)
return!1},
hE(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
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
jU(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.cm(a,b,r[o])
return A.hs(a,p,null,c,d.y,e)}return A.hs(a,b.y,null,c,d.y,e)},
hs(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.I(a,b[s],d,e[s],f))return!1
return!0},
jZ(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.I(a,r[s],c,q[s],e))return!1
return!0},
bB(a){var s=a.w,r=!0
if(!(a===t.P||a===t.T))if(!A.be(a))if(s!==6)r=s===7&&A.bB(a.x)
return r},
be(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.X},
hr(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
eo(a){return a>0?new Array(a):v.typeUniverse.sEA},
a6:function a6(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
de:function de(){this.c=this.b=this.a=null},
ek:function ek(a){this.a=a},
dd:function dd(){},
ci:function ci(a){this.a=a},
ja(){var s,r,q
if(self.scheduleImmediate!=null)return A.ky()
if(self.MutationObserver!=null&&self.document!=null){s={}
r=self.document.createElement("div")
q=self.document.createElement("span")
s.a=null
new self.MutationObserver(A.eJ(new A.dU(s),1)).observe(r,{childList:true})
return new A.dT(s,r,q)}else if(self.setImmediate!=null)return A.kz()
return A.kA()},
jb(a){self.scheduleImmediate(A.eJ(new A.dV(t.M.a(a)),0))},
jc(a){self.setImmediate(A.eJ(new A.dW(t.M.a(a)),0))},
jd(a){A.f9(B.j,t.M.a(a))},
f9(a,b){var s=B.c.N(a.a,1000)
return A.jn(s<0?0:s,b)},
jn(a,b){var s=new A.ei()
s.aW(a,b)
return s},
hH(a){return new A.da(new A.D($.z,a.h("D<0>")),a.h("da<0>"))},
hz(a,b){a.$2(0,null)
b.b=!0
return b.a},
hw(a,b){A.jB(a,b)},
hy(a,b){b.ah(a)},
hx(a,b){b.aI(A.af(a),A.bc(a))},
jB(a,b){var s,r,q=new A.es(b),p=new A.et(b)
if(a instanceof A.D)a.aB(q,p,t.z)
else{s=t.z
if(a instanceof A.D)a.an(q,p,s)
else{r=new A.D($.z,t._)
r.a=8
r.c=a
r.aB(q,p,s)}}},
hV(a){var s=function(b,c){return function(d,e){while(true){try{b(d,e)
break}catch(r){e=r
d=c}}}}(a,1)
return $.z.aL(new A.eG(s),t.H,t.S,t.z)},
dv(a){var s
if(t.C.b(a)){s=a.gT()
if(s!=null)return s}return B.D},
jQ(a,b){if($.z===B.f)return null
return null},
jR(a,b){if($.z!==B.f)A.jQ(a,b)
if(t.C.b(a))A.j_(a,b)
return new A.W(a,b)},
e1(a,b,c){var s,r,q,p,o={},n=o.a=a
for(s=t._;r=n.a,(r&4)!==0;n=a){a=s.a(n.c)
o.a=a}if(n===b){s=A.j3()
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
A.b3(b,p)
return}b.a^=2
A.dq(null,null,b.b,t.M.a(new A.e2(o,b)))},
b3(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d={},c=d.a=a
for(s=t.n,r=t.F;;){q={}
p=c.a
o=(p&16)===0
n=!o
if(b==null){if(n&&(p&1)===0){m=s.a(c.c)
A.fj(m.a,m.b)}return}q.a=b
l=b.a
for(c=b;l!=null;c=l,l=k){c.a=null
A.b3(d.a,c)
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
A.fj(j.a,j.b)
return}g=$.z
if(g!==h)$.z=h
else g=null
c=c.c
if((c&15)===8)new A.e6(q,d,n).$0()
else if(o){if((c&1)!==0)new A.e5(q,j).$0()}else if((c&2)!==0)new A.e4(d,q).$0()
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
continue}else A.e1(c,f,!0)
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
kk(a,b){var s
if(t.U.b(a))return b.aL(a,t.z,t.K,t.l)
s=t.v
if(s.b(a))return s.a(a)
throw A.f(A.du(a,"onError",u.c))},
k3(){var s,r
for(s=$.by;s!=null;s=$.by){$.cp=null
r=s.b
$.by=r
if(r==null)$.co=null
s.a.$0()}},
kr(){$.fh=!0
try{A.k3()}finally{$.cp=null
$.fh=!1
if($.by!=null)$.fr().$1(A.hX())}},
hT(a){var s=new A.db(a),r=$.co
if(r==null){$.by=$.co=s
if(!$.fh)$.fr().$1(A.hX())}else $.co=r.b=s},
ko(a){var s,r,q,p=$.by
if(p==null){A.hT(a)
$.cp=$.co
return}s=new A.db(a)
r=$.cp
if(r==null){s.b=p
$.by=$.cp=s}else{q=r.b
s.b=q
$.cp=r.b=s
if(q==null)$.co=s}},
lj(a,b){A.eI(a,"stream",t.K)
return new A.dj(b.h("dj<0>"))},
j6(a,b){var s=$.z
if(s===B.f)return A.f9(a,t.M.a(b))
return A.f9(a,t.M.a(s.aF(b)))},
fj(a,b){A.ko(new A.eF(a,b))},
hR(a,b,c,d,e){var s,r=$.z
if(r===c)return d.$0()
$.z=c
s=r
try{r=d.$0()
return r}finally{$.z=s}},
kn(a,b,c,d,e,f,g){var s,r=$.z
if(r===c)return d.$1(e)
$.z=c
s=r
try{r=d.$1(e)
return r}finally{$.z=s}},
km(a,b,c,d,e,f,g,h,i){var s,r=$.z
if(r===c)return d.$2(e,f)
$.z=c
s=r
try{r=d.$2(e,f)
return r}finally{$.z=s}},
dq(a,b,c,d){t.M.a(d)
if(B.f!==c){d=c.aF(d)
d=d}A.hT(d)},
dU:function dU(a){this.a=a},
dT:function dT(a,b,c){this.a=a
this.b=b
this.c=c},
dV:function dV(a){this.a=a},
dW:function dW(a){this.a=a},
ei:function ei(){this.b=null},
ej:function ej(a,b){this.a=a
this.b=b},
da:function da(a,b){this.a=a
this.b=!1
this.$ti=b},
es:function es(a){this.a=a},
et:function et(a){this.a=a},
eG:function eG(a){this.a=a},
W:function W(a,b){this.a=a
this.b=b},
dc:function dc(){},
c4:function c4(a,b){this.a=a
this.$ti=b},
b2:function b2(a,b,c,d,e){var _=this
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
dZ:function dZ(a,b){this.a=a
this.b=b},
e3:function e3(a,b){this.a=a
this.b=b},
e2:function e2(a,b){this.a=a
this.b=b},
e0:function e0(a,b){this.a=a
this.b=b},
e_:function e_(a,b){this.a=a
this.b=b},
e6:function e6(a,b,c){this.a=a
this.b=b
this.c=c},
e7:function e7(a,b){this.a=a
this.b=b},
e8:function e8(a){this.a=a},
e5:function e5(a,b){this.a=a
this.b=b},
e4:function e4(a,b){this.a=a
this.b=b},
e9:function e9(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ea:function ea(a,b,c){this.a=a
this.b=b
this.c=c},
eb:function eb(a,b){this.a=a
this.b=b},
db:function db(a){this.a=a
this.b=null},
dj:function dj(a){this.$ti=a},
cn:function cn(){},
di:function di(){},
eh:function eh(a,b){this.a=a
this.b=b},
eF:function eF(a,b){this.a=a
this.b=b},
iR(a,b){return new A.aj(a.h("@<0>").t(b).h("aj<1,2>"))},
p(a,b,c){return b.h("@<0>").t(c).h("fJ<1,2>").a(A.kX(a,new A.aj(b.h("@<0>").t(c).h("aj<1,2>"))))},
fK(a,b){return new A.aj(a.h("@<0>").t(b).h("aj<1,2>"))},
fL(a){return new A.c8(a.h("c8<0>"))},
fa(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
jg(a,b,c){var s=new A.b4(a,b,c.h("b4<0>"))
s.c=a.e
return s},
ak(a,b,c){var s=A.iR(b,c)
s.bb(0,a)
return s},
f3(a){var s,r
if(A.fp(a))return"{...}"
s=new A.b0("")
try{r={}
B.d.u($.a0,a)
s.a+="{"
r.a=!0
a.J(0,new A.dF(r,s))
s.a+="}"}finally{if(0>=$.a0.length)return A.c($.a0,-1)
$.a0.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
c8:function c8(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
dh:function dh(a){this.a=a
this.b=null},
b4:function b4(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
t:function t(){},
L:function L(){},
dF:function dF(a,b){this.a=a
this.b=b},
bt:function bt(){},
cg:function cg(){},
k4(a,b){var s,r,q,p=null
try{p=JSON.parse(a)}catch(r){s=A.af(r)
q=A.fD(String(s),null)
throw A.f(q)}q=A.eu(p)
return q},
eu(a){var s
if(a==null)return null
if(typeof a!="object")return a
if(!Array.isArray(a))return new A.df(a,Object.create(null))
for(s=0;s<a.length;++s)a[s]=A.eu(a[s])
return a},
fI(a,b,c){return new A.bL(a,b)},
jG(a){return a.bF()},
je(a,b){return new A.ed(a,[],A.kF())},
jf(a,b,c){var s,r=new A.b0(""),q=A.je(r,b)
q.Z(a)
s=r.a
return s.charCodeAt(0)==0?s:s},
df:function df(a,b){this.a=a
this.b=b
this.c=null},
dg:function dg(a){this.a=a},
cz:function cz(){},
cB:function cB(){},
bL:function bL(a,b){this.a=a
this.b=b},
cK:function cK(a,b){this.a=a
this.b=b},
cJ:function cJ(){},
dD:function dD(a){this.b=a},
dC:function dC(a){this.a=a},
ee:function ee(){},
ef:function ef(a,b){this.a=a
this.b=b},
ed:function ed(a,b,c){this.c=a
this.a=b
this.b=c},
dR:function dR(){},
en:function en(a){this.b=0
this.c=a},
iE(a,b){a=A.K(a,new Error())
if(a==null)a=A.bx(a)
a.stack=b.i(0)
throw a},
f2(a,b,c,d){var s,r=J.iM(a,d)
if(a!==0&&b!=null)for(s=0;s<a;++s)r[s]=b
return r},
iS(a,b,c){var s,r,q=A.w([],c.h("v<0>"))
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.cs)(a),++r)B.d.u(q,c.a(a[r]))
q.$flags=1
return q},
U(a,b){var s,r
if(Array.isArray(a))return A.w(a.slice(0),b.h("v<0>"))
s=A.w([],b.h("v<0>"))
for(r=J.ct(a);r.v();)B.d.u(s,r.gA())
return s},
f8(a){var s,r,q
A.f6(0,"start")
if(Array.isArray(a)){s=a
r=s.length
return A.h7(r<r?s.slice(0,r):s)}if(t.Z.b(a))return A.j5(a,0,null)
q=A.U(a,t.S)
return A.h7(q)},
j5(a,b,c){var s=a.length
if(b>=s)return""
return A.iZ(a,b,s)},
j1(a){return new A.cH(a,A.fH(a,!1,!0,!1,!1,""))},
hb(a,b,c){var s=J.ct(b)
if(!s.v())return a
if(c.length===0){do a+=A.e(s.gA())
while(s.v())}else{a+=A.e(s.gA())
while(s.v())a=a+c+A.e(s.gA())}return a},
j3(){return A.bc(new Error())},
iC(a,b,c,d,e,f){var s=A.j0(a,b,c,d,e,f,0,0,!0)
return new A.bE(s==null?new A.dx(a,b,c,d,e,f,0,0).$0():s,0,!0)},
fC(a){var s=Math.abs(a),r=a<0?"-":""
if(s>=1000)return""+a
if(s>=100)return r+"0"+s
if(s>=10)return r+"00"+s
return r+"000"+s},
iD(a){var s=Math.abs(a),r=a<0?"-":"+"
if(s>=1e5)return r+s
return r+"0"+s},
dy(a){if(a>=100)return""+a
if(a>=10)return"0"+a
return"00"+a},
ag(a){if(a>=10)return""+a
return"0"+a},
cC(a){if(typeof a=="number"||A.fg(a)||a==null)return J.ap(a)
if(typeof a=="string")return JSON.stringify(a)
return A.h6(a)},
iF(a,b){A.eI(a,"error",t.K)
A.eI(b,"stackTrace",t.l)
A.iE(a,b)},
cv(a){return new A.cu(a)},
aE(a,b){return new A.a2(!1,null,b,a)},
du(a,b,c){return new A.a2(!0,a,b,c)},
h8(a,b){return new A.ax(null,null,!0,a,b,"Value not in range")},
V(a,b,c,d,e){return new A.ax(b,c,!0,a,d,"Invalid value")},
h9(a,b,c){if(0>a||a>c)throw A.f(A.V(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.f(A.V(b,a,c,"end",null))
return b}return c},
f6(a,b){if(a<0)throw A.f(A.V(a,0,null,b,null))
return a},
eZ(a,b,c,d){return new A.cD(b,!0,a,d,"Index out of range")},
d9(a){return new A.c1(a)},
hd(a){return new A.d7(a)},
dO(a){return new A.c_(a)},
aI(a){return new A.cA(a)},
fD(a,b){return new A.dz(a,b)},
iL(a,b,c){var s,r
if(A.fp(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.w([],t.s)
B.d.u($.a0,a)
try{A.k2(a,s)}finally{if(0>=$.a0.length)return A.c($.a0,-1)
$.a0.pop()}r=A.hb(b,t.r.a(s),", ")+c
return r.charCodeAt(0)==0?r:r},
f_(a,b,c){var s,r
if(A.fp(a))return b+"..."+c
s=new A.b0(b)
B.d.u($.a0,a)
try{r=s
r.a=A.hb(r.a,a,", ")}finally{if(0>=$.a0.length)return A.c($.a0,-1)
$.a0.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
k2(a,b){var s,r,q,p,o,n,m,l=a.gC(a),k=0,j=0
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
fM(a,b,c,d,e){return new A.aH(a,b.h("@<0>").t(c).t(d).t(e).h("aH<1,2,3,4>"))},
y(a,b,c,d,e,f,g,h,i,j,k){var s
if(B.a===c){s=J.h(a)
b=J.h(b)
return A.ab(A.k(A.k($.a9(),s),b))}if(B.a===d){s=J.h(a)
b=J.h(b)
c=J.h(c)
return A.ab(A.k(A.k(A.k($.a9(),s),b),c))}if(B.a===e){s=J.h(a)
b=J.h(b)
c=J.h(c)
d=J.h(d)
return A.ab(A.k(A.k(A.k(A.k($.a9(),s),b),c),d))}if(B.a===f){s=J.h(a)
b=J.h(b)
c=J.h(c)
d=J.h(d)
e=J.h(e)
return A.ab(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e))}if(B.a===g){s=J.h(a)
b=J.h(b)
c=J.h(c)
d=J.h(d)
e=J.h(e)
f=J.h(f)
return A.ab(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f))}if(B.a===h){s=J.h(a)
b=J.h(b)
c=J.h(c)
d=J.h(d)
e=J.h(e)
f=J.h(f)
g=J.h(g)
return A.ab(A.k(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f),g))}if(B.a===i){s=J.h(a)
b=J.h(b)
c=J.h(c)
d=J.h(d)
e=J.h(e)
f=J.h(f)
g=J.h(g)
h=J.h(h)
return A.ab(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f),g),h))}if(B.a===j){s=J.h(a)
b=J.h(b)
c=J.h(c)
d=J.h(d)
e=J.h(e)
f=J.h(f)
g=J.h(g)
h=J.h(h)
i=J.h(i)
return A.ab(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f),g),h),i))}if(B.a===k){s=J.h(a)
b=J.h(b)
c=J.h(c)
d=J.h(d)
e=J.h(e)
f=J.h(f)
g=J.h(g)
h=J.h(h)
i=J.h(i)
j=J.h(j)
return A.ab(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f),g),h),i),j))}s=J.h(a)
b=J.h(b)
c=J.h(c)
d=J.h(d)
e=J.h(e)
f=J.h(f)
g=J.h(g)
h=J.h(h)
i=J.h(i)
j=J.h(j)
k=J.h(k)
k=A.ab(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k(A.k($.a9(),s),b),c),d),e),f),g),h),i),j),k))
return k},
bo(a){var s,r
t.J.a(a)
s=$.a9()
for(r=J.ct(a);r.v();)s=A.k(s,J.h(r.gA()))
return A.ab(s)},
dx:function dx(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
bE:function bE(a,b,c){this.a=a
this.b=b
this.c=c},
aK:function aK(a){this.a=a},
dX:function dX(){},
x:function x(){},
cu:function cu(a){this.a=a},
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
cD:function cD(a,b,c,d,e){var _=this
_.f=a
_.a=b
_.b=c
_.c=d
_.d=e},
c1:function c1(a){this.a=a},
d7:function d7(a){this.a=a},
c_:function c_(a){this.a=a},
cA:function cA(a){this.a=a},
cR:function cR(){},
bZ:function bZ(){},
dY:function dY(a){this.a=a},
dz:function dz(a,b){this.a=a
this.b=b},
i:function i(){},
as:function as(a,b,c){this.a=a
this.b=b
this.$ti=c},
F:function F(){},
o:function o(){},
dk:function dk(){},
b0:function b0(a){this.a=a},
kR(a,b){var s,r,q,p=A.a(a._malloc(4)),o=null
try{s=A.a(a._FPDF_GetFileVersion(b,p))
if(!J.d(s,0)){r=t.A.a(a.HEAP32)
q=p
if(typeof q!=="number")return q.bE()
q=B.b.k(q,2)
if(!(q<r.length))return A.c(r,q)
o=r[q]}}finally{a._free(p)}return new A.dI(o,A.hN(a,b,0),A.hN(a,b,1))},
i_(a,b,c){var s,r,q,p=A.a(a._FPDF_GetPageCount(b))
if(c<0||c>=p)throw A.f(A.V(c,0,p-1,"pageIndex",null))
s=A.a(a._FPDF_LoadPage(b,c))
if(J.d(s,0))throw A.f(A.f5(B.l))
try{r=A.eq(a._FPDF_GetPageWidthF(s))
q=A.eq(a._FPDF_GetPageHeightF(s))
return new A.cY(r,q)}finally{a._FPDF_ClosePage(s)}},
eP(a,b,c){var s,r,q,p=A.a(a._FPDF_GetPageCount(b)),o=c!=null
if(o)s=c<0||c>=p
else s=!1
if(s)throw A.f(A.V(c,0,p-1,"pageIndex",null))
if(o)o=A.w([c],t.t)
else{r=J.fE(p,t.S)
for(q=0;q<p;++q)r[q]=q
o=r}return o},
i0(a,b,c,d,e,f,g,h){var s,r,q,p,o,n,m,l,k,j=A.a(a._FPDF_GetPageCount(b))
if(c<0||c>=j)throw A.f(A.V(c,0,j-1,"pageIndex",null))
s=A.a(a._FPDF_LoadPage(b,c))
if(J.d(s,0))throw A.f(A.bX("FPDF_LoadPage returned null for page "+c+"."))
try{r=A.a(a._FPDFBitmap_Create(d,e,1))
if(J.d(r,0)){k=A.bX("FPDFBitmap_Create returned null for "+d+"x"+e+" (possible out-of-memory).")
throw A.f(k)}try{q=0
if(h){k=q
if(typeof k!=="number")return k.aR()
q=(k|1)>>>0}if(g){k=q
if(typeof k!=="number")return k.aR()
q=(k|2)>>>0}k=t.H
A.dr(a,"_FPDFBitmap_FillRect",[r,0,0,d,e,f],k)
A.dr(a,"_FPDF_RenderPageBitmap",[r,s,0,0,d,e,0,q],k)
p=A.a(a._FPDFBitmap_GetBuffer(r))
o=A.a(a._FPDFBitmap_GetStride(r))
k=o
if(typeof k!=="number")return k.E()
n=k*e
m=J.fs(B.i.gae(t.Z.a(a.HEAPU8)),p,n)
l=A.i7(m,d,e,o)
return new A.cf(e,d,l)}finally{a._FPDFBitmap_Destroy(r)}}finally{a._FPDF_ClosePage(s)}},
kS(a,b,c,d,e){var s,r,q,p,o,n,m,l,k
if(e<=0)throw A.f(A.du(e,"maxDimension","maxDimension must be greater than 0"))
p=A.a(a._FPDF_GetPageCount(b))
if(c<0||c>=p)throw A.f(A.V(c,0,p-1,"pageIndex",null))
s=A.a(a._FPDF_LoadPage(b,c))
if(J.d(s,0))throw A.f(A.bX("FPDF_LoadPage returned null for page "+c+"."))
try{r=A.a(a._FPDFPage_GetThumbnailAsBitmap(s))
if(!J.d(r,0))try{q=A.ki(a,r,c)
if(q!=null)return q}finally{a._FPDFBitmap_Destroy(r)}}finally{a._FPDF_ClosePage(s)}if(!d)return null
o=A.i_(a,b,c)
n=o.a
m=o.b
l=n>=m?e/n:e/m
k=A.i0(a,b,c,B.c.aH(B.b.aM(n*l),1,e),B.c.aH(B.b.aM(m*l),1,e),4294967295,!1,!0)
return new A.bW(k.c,k.b,k.a,B.an)},
ki(a,b,c){var s=A.a(a._FPDFBitmap_GetWidth(b)),r=A.a(a._FPDFBitmap_GetHeight(b)),q=A.a(a._FPDFBitmap_GetStride(b)),p=A.a(a._FPDFBitmap_GetFormat(b)),o=A.a(a._FPDFBitmap_GetBuffer(b)),n=A.kD(t.Z.a(a.HEAPU8),s,r,q,p,o)
if(n==null)return null
return new A.bW(n,s,r,B.am)},
fd(a,b){var s,r,q=B.C.be(b),p=q.length,o=p+1,n=A.a(a._malloc(o)),m=new Uint8Array(o)
for(s=0;s<p;++s){r=q[s]
if(!(s<o))return A.c(m,s)
m[s]=r}if(!(p<o))return A.c(m,p)
m[p]=0
A.fF(t.Z.a(a.HEAPU8),"set",m,n,t.X)
return n},
dp(a,b,c){var s,r,q,p,o=t.Z.a(a.HEAPU8),n=A.w([],t.t)
for(s=o.length,r=0;r<c;r+=2){q=b+r
if(!(q>=0&&q<s))return A.c(o,q)
p=o[q];++q
if(!(q<s))return A.c(o,q)
B.d.u(n,(p|o[q]<<8)>>>0)}return A.f8(n)},
eE(a,b){var s=t.A.a(a.HEAP32),r=B.c.k(b,2)
if(!(r<s.length))return A.c(s,r)
return s[r]>>>0},
b7(a,b,c){var s,r,q,p,o=A.fd(a,c)
try{s=A.a(a._FPDF_GetMetaText(b,o,0,0))
p=s
if(typeof p!=="number")return p.I()
if(p<=2)return null
r=A.a(a._malloc(s))
try{A.a(a._FPDF_GetMetaText(b,o,r,s))
p=s
if(typeof p!=="number")return p.a0()
q=A.dp(a,r,p-2)
p=J.Q(q)===0?null:q
return p}finally{a._free(r)}}finally{a._free(o)}},
hN(a,b,c){var s,r,q,p,o=A.a(a._FPDF_GetFileIdentifier(b,c,0,0))
if(J.d(o,0))return null
s=A.a(a._malloc(o))
try{A.a(a._FPDF_GetFileIdentifier(b,c,s,o))
r=t.Z.a(a.HEAPU8)
q=s
p=o
if(typeof q!=="number")return q.j()
if(typeof p!=="number")return A.S(p)
p=new Uint8Array(A.hB(B.i.a1(r,s,q+p)))
return p}finally{a._free(s)}},
kQ(a,b,c){var s,r,q,p,o,n,m,l,k,j,i,h=A.a(a._FPDF_LoadPage(b,c))
if(J.d(h,0))return new A.bq(c,"",!1,!1)
try{s=A.a(a._FPDFText_LoadPage(h))
if(J.d(s,0))return new A.bq(c,"",!1,!1)
try{r=A.a(a._FPDFText_CountChars(s))
q=!1
p=A.fL(t.S)
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
n=A.dp(a,m,(j-1)*2)}}finally{a._free(m)}}k=p.a===0?n:A.ks(n,p)
j=q
i=r
if(typeof i!=="number")return i.P()
return new A.bq(c,k,j,i>0)}finally{a._FPDFText_ClosePage(s)}}finally{a._FPDF_ClosePage(h)}},
ks(a,b){var s,r,q,p,o,n=new A.b0("")
for(s=a.length,r=!1,q=0;q<s;++q){p=a[q]
if(r)o=p==="\n"||p==="\r"||p===" "
else o=!1
r=!1
if(o)continue
if(b.aJ(0,q)){r=!0
continue}n.a+=p}s=n.a
return s.charCodeAt(0)==0?s:s},
kO(a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4=A.a(a5._FPDF_LoadPage(a6,a7))
if(J.d(a4,0))return B.M
try{s=A.a(a5._FPDFPage_GetAnnotCount(a4))
r=A.f2(s,null,!1,t.e)
a1=t.S
q=A.fK(a1,a1)
p=0
for(;;){a1=p
a2=s
if(typeof a1!=="number")return a1.F()
if(typeof a2!=="number")return A.S(a2)
if(!(a1<a2))break
A:{o=A.a(a5._FPDFPage_GetAnnot(a4,p))
if(J.d(o,0))break A
n=A.a(a5._FPDFAnnot_GetSubtype(o))
if(J.d(n,16)){J.bg(q,p,o)
break A}try{m=A.fi(a5,o,"Contents")
l=A.fi(a5,o,"T")
k=A.fi(a5,o,"M")
j=A.a(a5._FPDFAnnot_GetFlags(o))
i=A.hM(a5,o)
h=A.hL(a5,o,0)
J.bg(r,p,A.jC(o,l,h,m,a6,j,A.f4(k),a5,a7,a4,i,n))}finally{a5._FPDFPage_CloseAnnot(o)}}a1=p
if(typeof a1!=="number")return a1.j()
p=a1+1}g=A.fd(a5,"IRT")
try{for(a1=q,a1=new A.bM(a1,A.E(a1).h("bM<1,2>")).gC(0);a1.v();){a2=a1.d
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
a2=a2<a3&&J.eY(r,c)!=null}else a2=!1
if(a2){b=A.hM(a5,e)
a=A.a(a5._FPDFAnnot_GetFlags(e))
a0=new A.cZ(b,a)
a2=J.eY(r,c)
a2.toString
J.bg(r,c,A.kx(a2,a0))}}finally{a5._FPDFPage_CloseAnnot(d)}}finally{a5._FPDFPage_CloseAnnot(e)}}}finally{a5._free(g)}a1=r
a2=A.H(a1)
a3=a2.h("c2<1>")
a3=A.fA(new A.c2(a1,a2.h("b9(1)").a(new A.eO()),a3),a3.h("i.E"),t.d)
a1=A.U(a3,A.E(a3).h("i.E"))
return a1}finally{a5._FPDF_ClosePage(a4)}},
fi(a,b,c){var s,r,q,p,o=A.fd(a,c)
try{s=A.a(a._FPDFAnnot_GetStringValue(b,o,0,0))
p=s
if(typeof p!=="number")return p.I()
if(p<=2)return null
r=A.a(a._malloc(s))
try{A.a(a._FPDFAnnot_GetStringValue(b,o,r,s))
p=s
if(typeof p!=="number")return p.a0()
q=A.dp(a,r,p-2)
p=J.Q(q)===0?null:q
return p}finally{a._free(r)}}finally{a._free(o)}},
hM(a,b){var s,r,q,p,o,n,m=A.a(a._malloc(16))
try{s=A.a(a._FPDFAnnot_GetRect(b,m))
if(J.d(s,0))return null
r=t.E
q=r.a(a.HEAPF32)
p=B.c.k(m,2)
if(!(p<q.length))return A.c(q,p)
p=q[p]
q=m
if(typeof q!=="number")return q.j()
o=r.a(a.HEAPF32)
q=B.b.k(q+4,2)
if(!(q<o.length))return A.c(o,q)
q=o[q]
o=m
if(typeof o!=="number")return o.j()
n=r.a(a.HEAPF32)
o=B.b.k(o+8,2)
if(!(o<n.length))return A.c(n,o)
o=n[o]
n=m
if(typeof n!=="number")return n.j()
r=r.a(a.HEAPF32)
n=B.b.k(n+12,2)
if(!(n<r.length))return A.c(r,n)
n=r[n]
return new A.a5(p,n,o,q)}finally{a._free(m)}},
hL(a,b,c){var s,r,q,p,o,n,m,l=A.a(a._malloc(16)),k=l,j=l
if(typeof j!=="number")return j.j()
s=j+4
j=l
if(typeof j!=="number")return j.j()
r=j+8
j=l
if(typeof j!=="number")return j.j()
q=j+12
try{p=A.dr(a,"_FPDFAnnot_GetColor",[b,c,k,s,r,q],t.S)
if(J.d(p,0))return null
j=A.eE(a,k)
o=A.eE(a,s)
n=A.eE(a,r)
m=A.eE(a,q)
return new A.cS(j,o,n,m)}finally{a._free(l)}},
k8(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e=A.a(a._FPDFAnnot_CountAttachmentPoints(b))
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
m=B.c.k(r,2)
if(!(m<n.length))return A.c(n,m)
m=n[m]
n=r
if(typeof n!=="number")return n.j()
l=o.a(a.HEAPF32)
n=B.b.k(n+4,2)
if(!(n<l.length))return A.c(l,n)
n=l[n]
l=r
if(typeof l!=="number")return l.j()
k=o.a(a.HEAPF32)
l=B.b.k(l+8,2)
if(!(l<k.length))return A.c(k,l)
l=k[l]
k=r
if(typeof k!=="number")return k.j()
j=o.a(a.HEAPF32)
k=B.b.k(k+12,2)
if(!(k<j.length))return A.c(j,k)
k=j[k]
j=r
if(typeof j!=="number")return j.j()
i=o.a(a.HEAPF32)
j=B.b.k(j+16,2)
if(!(j<i.length))return A.c(i,j)
j=i[j]
i=r
if(typeof i!=="number")return i.j()
h=o.a(a.HEAPF32)
i=B.b.k(i+20,2)
if(!(i<h.length))return A.c(h,i)
i=h[i]
h=r
if(typeof h!=="number")return h.j()
g=o.a(a.HEAPF32)
h=B.b.k(h+24,2)
if(!(h<g.length))return A.c(g,h)
h=g[h]
g=r
if(typeof g!=="number")return g.j()
f=o.a(a.HEAPF32)
g=B.b.k(g+28,2)
if(!(g<f.length))return A.c(f,g)
J.a4(s,new A.av(new A.C(m,n),new A.C(l,k),new A.C(j,i),new A.C(h,f[g])))}n=q
if(typeof n!=="number")return n.j()
q=n+1}}finally{a._free(r)}return s},
kg(a,b,a0){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c
if(a0.length===0)return null
s=A.a(a._FPDFText_LoadPage(b))
if(J.d(s,0))return null
try{r=A.w([],t.s)
for(h=a0.length,g=0;g<a0.length;a0.length===h||(0,A.cs)(a0),++g){q=a0[g]
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
J.a4(r,A.dp(a,j,f*2))}finally{a._free(j)}}h=J.ir(r," ")
return h}finally{a._FPDFText_ClosePage(s)}},
kd(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g,f=A.a(a._FPDFAnnot_GetInkListCount(b))
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
i=B.b.k(j+i*8,2)
if(!(i<h.length))return A.c(h,i)
i=h[i]
h=p
j=m
if(typeof j!=="number")return j.E()
if(typeof h!=="number")return h.j()
g=l.a(a.HEAPF32)
j=B.b.k(h+j*8+4,2)
if(!(j<g.length))return A.c(g,j)
J.a4(n,new A.C(i,g[j]))
j=m
if(typeof j!=="number")return j.j()
m=j+1}J.a4(s,n)}finally{a._free(p)}}j=r
if(typeof j!=="number")return j.j()
r=j+1}return s},
k9(a,b){var s,r,q,p,o,n,m,l,k,j=A.a(a._FPDFAnnot_GetVertices(b,0,0))
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
m=B.b.k(n+m*8,2)
if(!(m<l.length))return A.c(l,m)
m=l[m]
l=s
n=p
if(typeof n!=="number")return n.E()
if(typeof l!=="number")return l.j()
k=o.a(a.HEAPF32)
n=B.b.k(l+n*8+4,2)
if(!(n<k.length))return A.c(k,n)
J.a4(q,new A.C(m,k[n]))
n=p
if(typeof n!=="number")return n.j()
p=n+1}return q}finally{a._free(s)}},
ke(a,b){var s,r,q,p,o,n,m=A.a(a._malloc(16))
try{r=m
if(typeof r!=="number")return r.j()
s=A.a(a._FPDFAnnot_GetLine(b,m,r+8))
if(J.d(s,0))return new A.bw(null,null)
r=t.E
q=r.a(a.HEAPF32)
p=B.c.k(m,2)
if(!(p<q.length))return A.c(q,p)
p=q[p]
q=m
if(typeof q!=="number")return q.j()
o=r.a(a.HEAPF32)
q=B.b.k(q+4,2)
if(!(q<o.length))return A.c(o,q)
q=o[q]
o=m
if(typeof o!=="number")return o.j()
n=r.a(a.HEAPF32)
o=B.b.k(o+8,2)
if(!(o<n.length))return A.c(n,o)
o=n[o]
n=m
if(typeof n!=="number")return n.j()
r=r.a(a.HEAPF32)
n=B.b.k(n+12,2)
if(!(n<r.length))return A.c(r,n)
n=r[n]
return new A.bw(new A.C(o,n),new A.C(p,q))}finally{a._free(m)}},
kf(a,b,c){var s,r=A.a(a._FPDFAnnot_GetLink(c))
if(r===0)return null
s=A.a(a._FPDFLink_GetAction(r))
if(s===0)return null
if(A.a(a._FPDFAction_GetType(s))!==3)return null
return A.hK(a,b,s)},
hK(a,b,c){var s,r,q,p,o,n=A.a(a._FPDFAction_GetURIPath(b,c,0,0))
if(J.d(n,0))return null
s=A.a(a._malloc(n))
try{A.a(a._FPDFAction_GetURIPath(b,c,s,n))
r=t.Z.a(a.HEAPU8)
p=s
o=n
if(typeof p!=="number")return p.j()
if(typeof o!=="number")return A.S(o)
q=A.f8(J.it(r,s,p+o-1))
p=J.Q(q)===0?null:q
return p}finally{a._free(s)}},
fe(a){var s
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
jC(a,b,c,d,e,f,g,h,i,a0,a1,a2){var s,r,q,p,o,n,m,l,k,j=null
if(a2===9||a2===10||a2===11||a2===12){s=A.fe(a2)
r=A.k8(h,a)
return A.fT(b,c,d,f,A.kg(h,a0,r),g,i,j,r,a1,s)}if(a2===5||a2===6){s=A.fe(a2)
return A.fV(b,c,d,f,A.hL(h,a,1),g,i,j,a1,s)}switch(a2){case 1:return A.fX(b,c,d,f,g,i,j,a1)
case 2:return A.fS(b,c,d,f,g,i,j,a1,A.kf(h,e,a))
case 3:return A.fP(b,c,d,f,g,i,j,a1)
case 4:q=A.ke(h,a)
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
return A.fR(b,c,d,f,k,l,g,i,j,a1)
case 7:case 8:return A.fU(b,c,d,f,g,i,j,a1,A.fe(a2),A.k9(h,a))
case 13:return A.fW(b,c,d,f,g,i,j,a1)
case 15:return A.fQ(b,c,d,f,g,i,j,a1,A.kd(h,a))
default:return A.fY(b,c,d,f,g,i,j,a2,a1)}},
kx(a,b){var s
A:{if(a instanceof A.aZ){s=A.fX(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d)
break A}if(a instanceof A.aR){s=A.fP(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d)
break A}if(a instanceof A.aV){s=A.fT(a.c,a.e,a.b,a.r,a.z,a.f,a.a,b,a.y,a.d,a.x)
break A}if(a instanceof A.aX){s=A.fV(a.c,a.e,a.b,a.r,a.y,a.f,a.a,b,a.d,a.x)
break A}if(a instanceof A.aT){s=A.fR(a.c,a.e,a.b,a.r,a.y,a.x,a.f,a.a,b,a.d)
break A}if(a instanceof A.aS){s=A.fQ(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d,a.x)
break A}if(a instanceof A.aW){s=A.fU(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d,a.x,a.y)
break A}if(a instanceof A.aU){s=A.fS(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d,a.x)
break A}if(a instanceof A.aY){s=A.fW(a.c,a.e,a.b,a.r,a.f,a.a,b,a.d)
break A}if(a instanceof A.b_){s=A.fY(a.c,a.e,a.b,a.r,a.f,a.a,b,a.x,a.d)
break A}s=null}return s},
kP(a2,a3,a4,a5){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=A.a(a2._FPDF_LoadPage(a3,a4))
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
f=B.c.k(o,2)
if(!(f<g.length))return A.c(g,f)
f=g[f]
g=o
if(typeof g!=="number")return g.j()
e=i.a(a2.HEAP32)
g=B.b.k(g+4,2)
if(!(g<e.length))return A.c(e,g)
g=e[g]
e=o
if(typeof e!=="number")return e.j()
d=h.a(a2.HEAPF32)
e=B.b.k(e+8,2)
if(!(e<d.length))return A.c(d,e)
e=d[e]
d=o
if(typeof d!=="number")return d.j()
c=h.a(a2.HEAPF32)
d=B.b.k(d+12,2)
if(!(d<c.length))return A.c(c,d)
d=c[d]
c=o
if(typeof c!=="number")return c.j()
b=i.a(a2.HEAP32)
c=B.b.k(c+16,2)
if(!(c<b.length))return A.c(b,c)
c=b[c]
b=o
if(typeof b!=="number")return b.j()
a=i.a(a2.HEAP32)
b=B.b.k(b+20,2)
if(!(b<a.length))return A.c(a,b)
b=A.jF(a[b])
a=o
if(typeof a!=="number")return a.j()
a0=i.a(a2.HEAP32)
a=B.b.k(a+24,2)
if(!(a<a0.length))return A.c(a0,a)
m=new A.cX(f>>>0,g>>>0,e,d,c>>>0,b,a0[a]>>>0)
a2._free(o)
l=A.kh(a2,p)
k=A.kc(a2,p)
j=null
if(a5)j=A.hO(a2,a3,a1,p)
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
kT(a,b,c,d){var s,r,q,p,o
if(d<0)throw A.f(A.h8(d,"objectIndex"))
p=A.a(a._FPDF_GetPageCount(b))
if(c<0||c>=p)throw A.f(A.V(c,0,p-1,"pageIndex",null))
s=A.a(a._FPDF_LoadPage(b,c))
if(J.d(s,0))throw A.f(A.f5(B.l))
try{r=A.a(a._FPDFPage_GetObject(s,d))
if(J.d(r,0))return null
q=A.a(a._FPDFPageObj_GetType(r))
if(!J.d(q,3))return null
o=A.hO(a,b,s,r)
return o}finally{a._FPDF_ClosePage(s)}},
kh(a,b){var s,r,q,p,o,n,m=A.a(a._malloc(16))
try{r=m
if(typeof r!=="number")return r.j()
q=m
if(typeof q!=="number")return q.j()
p=m
if(typeof p!=="number")return p.j()
s=A.dr(a,"_FPDFPageObj_GetBounds",[b,m,r+4,q+8,p+12],t.S)
if(J.d(s,0))return B.al
r=t.E
q=r.a(a.HEAPF32)
p=B.c.k(m,2)
if(!(p<q.length))return A.c(q,p)
p=q[p]
q=m
if(typeof q!=="number")return q.j()
o=r.a(a.HEAPF32)
q=B.b.k(q+4,2)
if(!(q<o.length))return A.c(o,q)
q=o[q]
o=m
if(typeof o!=="number")return o.j()
n=r.a(a.HEAPF32)
o=B.b.k(o+8,2)
if(!(o<n.length))return A.c(n,o)
o=n[o]
n=m
if(typeof n!=="number")return n.j()
r=r.a(a.HEAPF32)
n=B.b.k(n+12,2)
if(!(n<r.length))return A.c(r,n)
n=r[n]
return new A.a5(p,q,o,n)}finally{a._free(m)}},
kc(a,b){var s,r,q,p,o,n,m,l,k,j,i,h=A.a(a._FPDFImageObj_GetImageFilterCount(b))
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
n=A.f8(new Uint8Array(l.subarray(i,A.hA(i,k+j-1,J.Q(l)))))
if(J.Q(n)!==0)J.a4(s,n)}finally{a._free(p)}}l=r
if(typeof l!=="number")return l.j()
r=l+1}return s},
hO(a,b,c,d){var s,r,q,p,o,n,m,l,k,j=A.a(a._FPDFImageObj_GetRenderedBitmap(b,c,d))
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
n=J.fs(B.i.gae(t.Z.a(a.HEAPU8)),p,o)
m=A.i7(n,s,r,q)
return new A.cW(m,s,r)}finally{a._FPDFBitmap_Destroy(j)}},
jF(a){var s
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
kU(a2,a3,a4,a5,a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=A.a(a2._FPDF_LoadPage(a3,a4))
if(J.d(a1,0))return B.k
try{s=A.a(a2._FPDFText_LoadPage(a1))
if(J.d(s,0))return B.k
try{r=new A.cy(a5)
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
J.bg(p,f+e*2,c.charCodeAt(d)&255)
d=q
c=o
if(typeof c!=="number")return c.E()
if(typeof d!=="number")return d.j()
e=A.a(o)
f=r.a
if(!(e>=0&&e<f.length))return A.c(f,e)
J.bg(p,d+c*2+1,f.charCodeAt(e)>>>8&255)
f=o
if(typeof f!=="number")return f.j()
o=f+1}f=q
e=r.a
if(typeof f!=="number")return f.j()
J.bg(p,f+e.length*2,0)
e=q
f=r.a
if(typeof e!=="number")return e.j()
J.bg(p,e+f.length*2+1,0)
n=A.a(a2._FPDFText_FindStart(s,q,a6,0))
if(J.d(n,0))return B.k
m=A.w([],t.c)
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
b=B.c.k(h,3)
if(!(b<a.length))return A.c(a,b)
b=a[b]
a=h
if(typeof a!=="number")return a.j()
c=f.a(a2.HEAPF64)
a=B.b.k(a+8,3)
if(!(a<c.length))return A.c(c,a)
a=c[a]
c=h
if(typeof c!=="number")return c.j()
d=f.a(a2.HEAPF64)
c=B.b.k(c+16,3)
if(!(c<d.length))return A.c(d,c)
c=d[c]
d=h
if(typeof d!=="number")return d.j()
a0=f.a(a2.HEAPF64)
d=B.b.k(d+24,3)
if(!(d<a0.length))return A.c(a0,d)
J.a4(i,new A.a5(b,a0[d],c,a))
d=g
if(typeof d!=="number")return d.j()
g=d+1}}finally{a2._free(h)}J.a4(m,new A.bV(a4,l,k,i))}}finally{a2._FPDFText_FindClose(n)}return m}finally{a2._free(q)}}finally{a2._FPDFText_ClosePage(s)}}finally{a2._FPDF_ClosePage(a1)}},
hU(a,b,c,d){var s,r,q=A.w([],t.a9),p=A.a(a._FPDFBookmark_GetFirstChild(b,c))
while(p!==0){if(d.aJ(0,p))break
d.u(0,p)
s=A.ka(a,p)
r=A.kl(a,b,p)
B.d.u(q,new A.aw(s,r.a,r.c,r.b,A.hU(a,b,p,d)))
p=A.a(a._FPDFBookmark_GetNextSibling(b,p))}return q},
ka(a,b){var s,r=A.a(a._FPDFBookmark_GetTitle(b,0,0)),q=r
if(typeof q!=="number")return q.I()
if(q<=2)return""
s=A.a(a._malloc(r))
try{A.a(a._FPDFBookmark_GetTitle(b,s,r))
q=r
if(typeof q!=="number")return q.a0()
q=A.dp(a,s,q-2)
return q}finally{a._free(s)}},
kl(a,b,c){var s,r,q=null,p=A.a(a._FPDFBookmark_GetAction(c))
if(p!==0){s=A.a(a._FPDFAction_GetType(p))
if(s===1){r=A.a(a._FPDFAction_GetDest(b,p))
if(r!==0)return new A.ae(A.hP(a,b,r),A.hQ(a,r),q)
return new A.ae(q,q,q)}if(s===3)return new A.ae(q,q,A.hK(a,b,p))
return new A.ae(q,q,q)}r=A.a(a._FPDFBookmark_GetDest(b,c))
if(r!==0)return new A.ae(A.hP(a,b,r),A.hQ(a,r),q)
return new A.ae(q,q,q)},
hP(a,b,c){var s=A.a(a._FPDFDest_GetDestPageIndex(b,c))
return s<0?null:s},
hQ(a,b){var s,r,q,p,o,n,m,l,k,j,i=A.a(a._malloc(24)),h=i,g=i
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
try{n=A.dr(a,"_FPDFDest_GetLocationInPage",[b,h,s,r,q,p,o],t.S)
if(J.d(n,0))return null
g=t.A
k=g.a(a.HEAP32)
j=B.c.k(h,2)
if(!(j<k.length))return A.c(k,j)
m=k[j]!==0
g=g.a(a.HEAP32)
j=B.c.k(s,2)
if(!(j<g.length))return A.c(g,j)
l=g[j]!==0
if(!m&&!l)return null
if(m){g=t.E.a(a.HEAPF32)
k=B.c.k(q,2)
if(!(k<g.length))return A.c(g,k)
k=g[k]
g=k}else g=0
if(l){k=t.E.a(a.HEAPF32)
j=B.c.k(p,2)
if(!(j<k.length))return A.c(k,j)
j=k[j]
k=j}else k=0
return new A.C(g,k)}finally{a._free(i)}},
eO:function eO(){},
l7(){var s,r=v.G,q=new A.eV(r,new A.ep(A.fK(t.S,t.bq)))
if(typeof q=="function")A.a1(A.aE("Attempting to rewrap a JS function.",null))
s=function(a,b){return function(c){return a(b,c,arguments.length)}}(A.jE,q)
s[$.eX()]=q
r.addEventListener("message",s)},
ev(a,b,c){return A.jM(a,b,c)},
jM(f8,f9,g0){var s=0,r=A.hH(t.H),q,p=2,o=[],n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,d0,d1,d2,d3,d4,d5,d6,d7,d8,d9,e0,e1,e2,e3,e4,e5,e6,e7,e8,e9,f0,f1,f2,f3,f4,f5,f6,f7
var $async$ev=A.hV(function(g1,g2){if(g1===1){o.push(g2)
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
case 9:if(g0.b==null)g0.sbr(A.eA(f8))
e1=g0.a
s=e1==null?24:25
break
case 24:e0=g0.b
e0.toString
s=26
return A.hw(e0,$async$ev)
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
if(e4===0)A.a1(A.bX("WASM _malloc("+e3+") returned null \u2014 out of WASM heap memory."))
A.fF(t.Z.a(e0.HEAPU8),"set",e2,e4,t.X)
h=A.a(e0._FPDF_LoadMemDocument64(e4,e3,0))
if(h===0){e0._free(e4)
A.a1(A.f5(A.a(e0._FPDF_GetLastError())===4?B.ak:B.l))}l=new A.cd(e4,h)
k=g0.d++
g0.c.q(0,k,l)
A.P(f8,new A.J(f9.a,!0,A.p(["token",k],t.N,t.z),null,null,B.e))
s=8
break
case 10:e0=f9.c
j=A.a(e0.$ti.h("4?").a(e0.a.l(0,"token")))
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
A.P(f8,new A.J(f9.a,!0,A.p(["count",g],t.N,t.z),null,null,B.e))
s=8
break
case 12:f=A.a7(g0.c,f9)
e0=g0.a
e0.toString
e2=f
e=new A.dL(A.b7(e0,e2,"Title"),A.b7(e0,e2,"Author"),A.b7(e0,e2,"Subject"),A.b7(e0,e2,"Keywords"),A.b7(e0,e2,"Creator"),A.b7(e0,e2,"Producer"),A.f4(A.b7(e0,e2,"CreationDate")),A.f4(A.b7(e0,e2,"ModDate")))
e2=e
A.P(f8,new A.J(f9.a,!0,A.p(["title",e2.a,"author",e2.b,"subject",e2.c,"keywords",e2.d,"creator",e2.e,"producer",e2.f,"creationDate",A.fm(e2.r),"modDate",A.fm(e2.w)],t.N,t.z),null,null,B.e))
s=8
break
case 13:d=A.a7(g0.c,f9)
e0=g0.a
e0.toString
c=A.kR(e0,d)
e0=c
A.P(f8,new A.J(f9.a,!0,A.p(["fileVersion",e0.a,"permanentId",e0.b,"changingId",e0.c],t.N,t.z),null,null,B.e))
s=8
break
case 14:b=A.a7(g0.c,f9)
e0=f9.c
a=A.a(e0.$ti.h("4?").a(e0.a.l(0,"pageIndex")))
e0=g0.a
e0.toString
a0=A.i_(e0,b,a)
e0=a0
A.P(f8,new A.J(f9.a,!0,A.p(["widthPt",e0.a,"heightPt",e0.b],t.N,t.z),null,null,B.e))
s=8
break
case 15:a1=A.a7(g0.c,f9)
a2=f9.c
e0=g0.a
e0.toString
e2=a2
e2=A.a(e2.$ti.h("4?").a(e2.a.l(0,"pageIndex")))
e3=a2
e3=A.a(e3.$ti.h("4?").a(e3.a.l(0,"pixelWidth")))
e5=a2
e5=A.a(e5.$ti.h("4?").a(e5.a.l(0,"pixelHeight")))
e6=a2
e6=A.dl(e6.$ti.h("4?").a(e6.a.l(0,"renderAnnotations")))
e7=a2
e7=A.dl(e7.$ti.h("4?").a(e7.a.l(0,"lcdText")))
e8=a2
a3=A.i0(e0,a1,e2,e3,e5,A.a(e8.$ti.h("4?").a(e8.a.l(0,"backgroundColor"))),e7,e6)
a4=A.w([],t.a)
e6=a3
e7=a4
e8=J.aB(e7)
e8.u(e7,e6.c)
A.P(f8,new A.J(f9.a,!0,A.p(["bufIndex",e8.gp(e7)-1,"pixelWidth",e6.b,"pixelHeight",e6.a],t.N,t.z),null,null,a4))
s=8
break
case 16:a5=A.a7(g0.c,f9)
a6=f9.c
e0=g0.a
e0.toString
e2=a6
e3=a6
e5=a6
a7=A.kS(e0,a5,A.a(e2.$ti.h("4?").a(e2.a.l(0,"pageIndex"))),A.dl(e3.$ti.h("4?").a(e3.a.l(0,"generateIfAbsent"))),A.a(e5.$ti.h("4?").a(e5.a.l(0,"maxDimension"))))
e0=f9.a
if(a7==null)A.P(f8,new A.J(e0,!0,B.P,null,null,B.e))
else{a8=A.w([],t.a)
e2=a7
e3=a8
e5=J.aB(e3)
e5.u(e3,e2.a)
e6=t.N
e7=t.z
A.P(f8,new A.J(e0,!0,A.p(["thumbnail",A.p(["bufIndex",e5.gp(e3)-1,"width",e2.b,"height",e2.c,"source",e2.d.b],e6,e7)],e6,e7),null,null,a8))}s=8
break
case 17:a9=A.a7(g0.c,f9)
e0=f9.c
b0=A.dm(e0.$ti.h("4?").a(e0.a.l(0,"pageIndex")))
e0=g0.a
e0.toString
b1=A.eP(e0,a9,b0)
e0=b1
e2=A.H(e0)
e3=e2.h("q<1,l<j,@>>")
b6=A.U(new A.q(e0,e2.h("l<j,@>(1)").a(new A.ew(g0,a9)),e3),e3.h("B.E"))
b2=b6
A.P(f8,new A.J(f9.a,!0,A.p(["pages",b2],t.N,t.z),null,null,B.e))
s=8
break
case 18:b3=A.a7(g0.c,f9)
e0=f9.c
b4=A.dm(e0.$ti.h("4?").a(e0.a.l(0,"pageIndex")))
e0=g0.a
e0.toString
b5=A.eP(e0,b3,b4)
e0=b5
e2=A.H(e0)
e3=e2.h("q<1,l<j,@>>")
b2=A.U(new A.q(e0,e2.h("l<j,@>(1)").a(new A.ex(g0,b3)),e3),e3.h("B.E"))
b6=b2
A.P(f8,new A.J(f9.a,!0,A.p(["pages",b6],t.N,t.z),null,null,B.e))
s=8
break
case 19:b7=A.a7(g0.c,f9)
b8=f9.c
e0=b8
b9=A.dm(e0.$ti.h("4?").a(e0.a.l(0,"pageIndex")))
e0=b8
c0=A.dl(e0.$ti.h("4?").a(e0.a.l(0,"includeBitmap")))
e0=g0.a
e0.toString
c1=A.eP(e0,b7,b9)
c2=A.w([],t.a)
e0=c1
e2=A.H(e0)
e3=e2.h("q<1,l<j,@>>")
b2=A.U(new A.q(e0,e2.h("l<j,@>(1)").a(new A.ey(g0,b7,c0,c2)),e3),e3.h("B.E"))
c3=b2
A.P(f8,new A.J(f9.a,!0,A.p(["pages",c3],t.N,t.z),null,null,c2))
s=8
break
case 20:c4=A.a7(g0.c,f9)
c5=f9.c
e0=g0.a
e0.toString
e2=c5
e3=c5
c6=A.kT(e0,c4,A.a(e2.$ti.h("4?").a(e2.a.l(0,"pageIndex"))),A.a(e3.$ti.h("4?").a(e3.a.l(0,"objectIndex"))))
e0=f9.a
if(c6==null)A.P(f8,new A.J(e0,!0,B.Q,null,null,B.e))
else{c7=A.w([],t.a)
e2=c6
e3=c7
e5=J.aB(e3)
e5.u(e3,e2.a)
e6=t.N
e7=t.z
A.P(f8,new A.J(e0,!0,A.p(["bitmap",A.p(["bufIndex",e5.gp(e3)-1,"width",e2.b,"height",e2.c],e6,e7)],e6,e7),null,null,c7))}s=8
break
case 21:c8=A.a7(g0.c,f9)
c9=f9.c
e0=c9
d0=A.ao(e0.$ti.h("4?").a(e0.a.l(0,"query")))
e0=c9
d1=A.a(e0.$ti.h("4?").a(e0.a.l(0,"flagsMask")))
e0=c9
d2=A.dm(e0.$ti.h("4?").a(e0.a.l(0,"pageIndex")))
d3=A.w([],t.bG)
if(J.Q(d0)!==0){e0=g0.a
e0.toString
d4=A.eP(e0,c8,d2)
for(e0=d4,e2=e0.length,e3=t.N,e5=t.z,e9=0;e9<e0.length;e0.length===e2||(0,A.cs)(e0),++e9){d5=e0[e9]
e6=g0.a
e6.toString
e6=A.kU(e6,c8,d5,d0,d1)
e7=e6.length
f0=0
for(;f0<e6.length;e6.length===e7||(0,A.cs)(e6),++f0){d6=e6[f0]
e8=d6
f1=e8.a
f2=e8.b
f3=e8.c
e8=e8.d
f4=A.H(e8)
f5=f4.h("q<1,l<j,@>>")
e8=A.U(new A.q(e8,f4.h("l<j,@>(1)").a(A.k7()),f5),f5.h("B.E"))
J.a4(d3,A.p(["pageIndex",f1,"charIndex",f2,"charCount",f3,"rects",e8],e3,e5))}}}A.P(f8,new A.J(f9.a,!0,A.p(["matches",d3],t.N,t.z),null,null,B.e))
s=8
break
case 22:d7=A.a7(g0.c,f9)
e0=g0.a
e0.toString
d8=A.hU(e0,d7,0,A.fL(t.S))
e0=d8
e2=A.H(e0)
e3=e2.h("q<1,l<j,@>>")
e0=A.U(new A.q(e0,e2.h("l<j,@>(1)").a(A.hJ()),e3),e3.h("B.E"))
A.P(f8,new A.J(f9.a,!0,A.p(["entries",e0],t.N,t.z),null,null,B.e))
s=8
break
case 23:A.P(f8,A.he(f9.a,new A.br("Unknown worker op: "+e0)))
case 8:p=2
s=6
break
case 4:p=3
f7=o.pop()
d9=A.af(f7)
A.P(f8,A.he(f9.a,d9))
s=6
break
case 3:s=2
break
case 6:case 1:return A.hy(q,r)
case 2:return A.hx(o.at(-1),r)}})
return A.hz($async$ev,r)},
a7(a,b){var s=b.c,r=a.l(0,A.a(s.$ti.h("4?").a(s.a.l(0,"token"))))
if(r==null)throw A.f(A.dO("PdfDocument has already been closed."))
return r.b},
P(a,b){var s=A.kB(b)
a.postMessage(s.a,s.b)},
eA(a){var s=0,r=A.hH(t.m),q,p=2,o=[],n,m,l,k,j,i,h,g
var $async$eA=A.hV(function(b,c){if(b===1){o.push(c)
s=p}for(;;)switch(s){case 0:j=new A.c4(new A.D($.z,t.D),t.aY)
i={}
h=new A.eB(j)
if(typeof h=="function")A.a1(A.aE("Attempting to rewrap a JS function.",null))
m=function(d,e){return function(){return d(e)}}(A.jD,h)
m[$.eX()]=h
i.onRuntimeInitialized=m
a.Module=i
a.importScripts("pdfium.js")
p=4
s=7
return A.hw(j.a.bv(B.E,new A.eC()),$async$eA)
case 7:p=2
s=6
break
case 4:p=3
g=o.pop()
n=A.af(g)
if(n instanceof A.br)throw g
throw A.f(A.bX("PDFium WASM module failed to initialise inside the PDFium Worker: "+A.e(n)))
s=6
break
case 3:s=2
break
case 6:k=A.er(a.Module)
k._FPDF_InitLibraryWithConfig(0)
q=k
s=1
break
case 1:return A.hy(q,r)
case 2:return A.hx(o.at(-1),r)}})
return A.hz($async$eA,r)},
ep:function ep(a){var _=this
_.b=_.a=null
_.c=a
_.d=1},
eV:function eV(a,b){this.a=a
this.b=b},
ew:function ew(a,b){this.a=a
this.b=b},
ex:function ex(a,b){this.a=a
this.b=b},
ey:function ey(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eB:function eB(a){this.a=a},
eC:function eC(){},
he(a,b){var s=A.kC(b)
return new A.J(a,!1,null,s.b,s.a,B.e)},
kC(a){var s
A:{if(t.G.b(a)){s=a.d
s=s==null?null:J.ap(s)
s=new A.ad(s==null?a.i(0):s,"RangeError")
break A}if(a instanceof A.a2){s=a.d
s=s==null?null:J.ap(s)
s=new A.ad(s==null?a.i(0):s,"ArgumentError")
break A}if(a instanceof A.c_){s=new A.ad(a.a,"StateError")
break A}if(a instanceof A.cV){s=new A.ad(a.a.b,"PdfExtractionException")
break A}if(a instanceof A.br){s=new A.ad(a.a,"PdfiumException")
break A}s=new A.ad(J.ap(a),"Exception")
break A}return s},
fm(a){var s,r
if(a==null)s=null
else{s=a.a
r=a.b
s=A.p(["raw",s,"value",r==null?null:r.bw()],t.N,t.z)}return s},
eN(a){t.O.a(a)
return A.p(["left",a.a,"bottom",a.b,"right",a.c,"top",a.d],t.N,t.z)},
hZ(a){return A.p(["r",a.a,"g",a.b,"b",a.c,"a",a.d],t.N,t.z)},
kL(a){t.w.a(a)
return A.p(["x",a.a,"y",a.b],t.N,t.z)},
kM(a){var s,r,q,p,o,n
t.u.a(a)
s=a.a
r=t.N
q=t.z
p=a.b
o=a.c
n=a.d
return A.p(["p1",A.p(["x",s.a,"y",s.b],r,q),"p2",A.p(["x",p.a,"y",p.b],r,q),"p3",A.p(["x",o.a,"y",o.b],r,q),"p4",A.p(["x",n.a,"y",n.b],r,q)],r,q)},
kN(a){var s,r,q,p
t.b.a(a)
s=a.d
s=s==null?null:A.p(["x",s.a,"y",s.b],t.N,t.z)
r=a.e
q=A.H(r)
p=q.h("q<1,l<j,@>>")
r=A.U(new A.q(r,q.h("l<j,@>(1)").a(A.hJ()),p),p.h("B.E"))
return A.p(["title",a.a,"pageIndex",a.b,"uri",a.c,"scrollPosition",s,"children",r],t.N,t.z)},
kJ(a){var s,r,q,p,o,n,m,l=null,k="kind",j="subtype"
t.d.a(a)
s=a.d
s=s==null?l:A.eN(s)
r=a.e
r=r==null?l:A.hZ(r)
q=A.fm(a.f)
p=a.w
if(p==null)p=l
else{o=p.a
o=o==null?l:A.eN(o)
p=A.p(["rect",o,"flags",p.b],t.N,t.z)}o=t.N
n=t.z
m=A.p(["pageIndex",a.a,"contents",a.b,"author",a.c,"rect",s,"color",r,"modifiedDate",q,"flags",a.r,"popup",p],o,n)
A:{if(a instanceof A.aZ){s=A.ak(m,o,n)
s.q(0,k,"text")
break A}if(a instanceof A.aR){s=A.ak(m,o,n)
s.q(0,k,"freeText")
break A}if(a instanceof A.aV){s=A.ak(m,o,n)
s.q(0,k,"markup")
s.q(0,j,a.x.b)
r=a.y
q=A.H(r)
p=q.h("q<1,l<j,@>>")
r=A.U(new A.q(r,q.h("l<j,@>(1)").a(A.k6()),p),p.h("B.E"))
s.q(0,"quadPoints",r)
s.q(0,"markedText",a.z)
break A}if(a instanceof A.aX){s=A.ak(m,o,n)
s.q(0,k,"shape")
s.q(0,j,a.x.b)
r=a.y
s.q(0,"interiorColor",r==null?l:A.hZ(r))
break A}if(a instanceof A.aT){s=A.ak(m,o,n)
s.q(0,k,"line")
r=a.x
s.q(0,"lineStart",A.p(["x",r.a,"y",r.b],o,n))
r=a.y
s.q(0,"lineEnd",A.p(["x",r.a,"y",r.b],o,n))
break A}if(a instanceof A.aS){s=A.ak(m,o,n)
s.q(0,k,"ink")
r=a.x
q=A.H(r)
p=q.h("q<1,n<l<j,@>>>")
r=A.U(new A.q(r,q.h("n<l<j,@>>(1)").a(new A.eL()),p),p.h("B.E"))
s.q(0,"strokes",r)
break A}if(a instanceof A.aW){s=A.ak(m,o,n)
s.q(0,k,"polygon")
s.q(0,j,a.x.b)
r=a.y
q=A.H(r)
p=q.h("q<1,l<j,@>>")
r=A.U(new A.q(r,q.h("l<j,@>(1)").a(A.hI()),p),p.h("B.E"))
s.q(0,"vertices",r)
break A}if(a instanceof A.aU){s=A.ak(m,o,n)
s.q(0,k,"link")
s.q(0,"uri",a.x)
break A}if(a instanceof A.aY){s=A.ak(m,o,n)
s.q(0,k,"stamp")
break A}if(a instanceof A.b_){s=A.ak(m,o,n)
s.q(0,k,"unknown")
s.q(0,"rawSubtype",a.x)
break A}s=l}return s},
kK(a,b){var s=a.b,r=A.H(s),q=r.h("q<1,l<j,@>>")
s=A.U(new A.q(s,r.h("l<j,@>(1)").a(new A.eM(b)),q),q.h("B.E"))
return A.p(["pageIndex",a.a,"images",s],t.N,t.z)},
dS:function dS(a,b,c,d){var _=this
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
eL:function eL(){},
eM:function eM(a){this.a=a},
kB(a){var s=a.f,r=A.H(s),q=r.h("q<1,aa>"),p=A.U(new A.q(s,r.h("aa(1)").a(new A.eH()),q),q.h("B.E")),o={}
o.id=a.a
o.ok=a.b
s=a.c
o.json=B.p.bh(s==null?B.r:s,null)
o.buffers=p
s=a.d
if(s!=null)o.errorType=s
s=a.e
if(s!=null)o.errorMessage=s
return new A.ce(o,p)},
kb(a){var s=t.cm.a(a.buffers)
s=B.d.Y(s,new A.eD(),t.p)
s=A.U(s,s.$ti.h("B.E"))
return s},
eH:function eH(){},
eD:function eD(){},
dn(a,b,c){var s,r
if(a.length!==b.length)return!1
for(s=0;s<a.length;++s){r=a[s]
if(!(s<b.length))return A.c(b,s)
if(!J.d(r,b[s]))return!1}return!0},
f5(a){return new A.cV(a)},
fX(a,b,c,d,e,f,g,h){return new A.aZ(f,c,a,h,b,e,d,g)},
fP(a,b,c,d,e,f,g,h){return new A.aR(f,c,a,h,b,e,d,g)},
fT(a,b,c,d,e,f,g,h,i,j,k){return new A.aV(k,i,e,g,c,a,j,b,f,d,h)},
fV(a,b,c,d,e,f,g,h,i,j){return new A.aX(j,e,g,c,a,i,b,f,d,h)},
fR(a,b,c,d,e,f,g,h,i,j){return new A.aT(f,e,h,c,a,j,b,g,d,i)},
fQ(a,b,c,d,e,f,g,h,i){return new A.aS(i,f,c,a,h,b,e,d,g)},
iV(a,b){var s,r,q,p,o,n,m,l,k=a.length,j=b.length
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
fU(a,b,c,d,e,f,g,h,i,j){return new A.aW(i,j,f,c,a,h,b,e,d,g)},
fS(a,b,c,d,e,f,g,h,i){return new A.aU(i,f,c,a,h,b,e,d,g)},
fW(a,b,c,d,e,f,g,h){return new A.aY(f,c,a,h,b,e,d,g)},
fY(a,b,c,d,e,f,g,h,i){return new A.b_(h,f,c,a,i,b,e,d,g)},
cU:function cU(a,b){this.a=a
this.b=b},
cV:function cV(a){this.a=a},
cT:function cT(a,b){this.a=a
this.b=b},
dL:function dL(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
bq:function bq(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
M:function M(a,b){this.a=a
this.b=b},
cS:function cS(a,b,c,d){var _=this
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
cZ:function cZ(a,b){this.a=a
this.b=b},
G:function G(){},
aZ:function aZ(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
aR:function aR(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
aV:function aV(a,b,c,d,e,f,g,h,i,j,k){var _=this
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
aT:function aT(a,b,c,d,e,f,g,h,i,j){var _=this
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
aS:function aS(a,b,c,d,e,f,g,h,i){var _=this
_.x=a
_.a=b
_.b=c
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i},
aW:function aW(a,b,c,d,e,f,g,h,i,j){var _=this
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
aU:function aU(a,b,c,d,e,f,g,h,i){var _=this
_.x=a
_.a=b
_.b=c
_.c=d
_.d=e
_.e=f
_.f=g
_.r=h
_.w=i},
aY:function aY(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
b_:function b_(a,b,c,d,e,f,g,h,i){var _=this
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
cX:function cX(a,b,c,d,e,f,g){var _=this
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
cW:function cW(a,b,c){this.a=a
this.b=b
this.c=c},
dM:function dM(a,b){this.a=a
this.b=b},
bV:function bV(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
d_:function d_(a,b){this.a=a
this.b=b},
bW:function bW(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dI:function dI(a,b,c){this.a=a
this.b=b
this.c=c},
dJ:function dJ(){},
dK:function dK(){},
bX(a){return new A.br(a)},
br:function br(a){this.a=a},
cY:function cY(a,b){this.a=a
this.b=b},
lb(a){throw A.K(new A.cL("Field '"+a+"' has been assigned during initialization."),new Error())},
iO(a,b,c,d,e,f){var s=a[b](c,d)
return s},
fF(a,b,c,d,e){return e.a(A.iO(a,b,c,d,null,null))},
jD(a){return t.Y.a(a).$0()},
jE(a,b,c){t.Y.a(a)
if(A.a(c)>=1)return a.$1(b)
return a.$0()},
dr(a,b,c,d){return d.a(a[b].apply(a,c))},
i7(a,b,c,d){var s,r,q,p=b*4
if(d===p)return new Uint8Array(A.hB(a))
s=new Uint8Array(b*c*4)
for(r=0;r<c;++r){q=r*p
B.i.aS(s,q,q+p,a,r*d)}return s},
kD(a,b,c,d,e,f){var s,r,q,p,o,n,m,l,k,j,i,h,g=4
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
f4(a){if(a==null||a.length===0)return null
return new A.cT(a,A.iU(a))},
iU(b1){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8=null,a9=1000,b0=b1
if(J.fu(b0,"D:")||J.fu(b0,"d:"))b0=J.fv(b0,2)
b0=J.iu(b0)
if(J.Q(b0)<4)return a8
try{s=A.bp(b0,0,4)
if(s==null)return a8
if(J.Q(b0)>=6){f=A.bp(b0,4,6)
e=f==null?1:f}else e=1
r=e
if(J.Q(b0)>=8){f=A.bp(b0,6,8)
d=f==null?1:f}else d=1
q=d
if(J.Q(b0)>=10){f=A.bp(b0,8,10)
c=f==null?0:f}else c=0
p=c
if(J.Q(b0)>=12){f=A.bp(b0,10,12)
b=f==null?0:f}else b=0
o=b
if(J.Q(b0)>=14){f=A.bp(b0,12,14)
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
if(J.Q(b0)>14){l=J.eY(b0,14)
if(J.d(l,"Z")||J.d(l,"z"))m=B.j
else if(J.d(l,"+")||J.d(l,"-")){k=J.fv(b0,15)
j=A.fO(k,0)
i=A.fO(k,2)
f=j
if(f==null)f=0
if(typeof f!=="number")return f.E()
a0=i
if(a0==null)a0=0
if(typeof a0!=="number")return A.S(a0)
h=f*60+a0
m=new A.aK(6e7*(J.d(l,"+")?h:J.im(h)))}}g=A.iC(s,r,q,p,o,n)
f=g
a0=0-t.x.a(m).a
a1=B.c.a_(a0,a9)
a2=B.c.N(a0-a1,a9)
a3=f.b+a1
a4=B.c.a_(a3,a9)
a5=B.c.N(a3-a4,a9)
a6=f.a+a5+a2
if(a6<-864e13||a6>864e13)A.a1(A.V(a6,-864e13,864e13,"millisecondsSinceEpoch",a8))
if(a6===864e13&&a4!==0)A.a1(A.du(a4,"microsecond","Time including microseconds is outside valid range"))
A.eI(!0,"isUtc",t.y)
return new A.bE(a6,a4,!0)}catch(a7){return a8}},
bp(a,b,c){var s=a.length
if(c>s)c=s
if(b>=c)return null
return A.iX(B.h.L(a,b,c),null)},
fO(a,b){var s=A.j1("[^0-9]")
return A.bp(A.la(a,s,""),b,b+2)}},B={}
var w=[A,J,B]
var $={}
A.f0.prototype={}
J.cE.prototype={
n(a,b){return a===b},
gm(a){return A.d2(a)},
i(a){return"Instance of '"+A.d3(a)+"'"},
gD(a){return A.ba(A.ff(this))}}
J.cG.prototype={
i(a){return String(a)},
gm(a){return a?519018:218159},
gD(a){return A.ba(t.y)},
$iu:1,
$ib9:1}
J.bH.prototype={
n(a,b){return null==b},
i(a){return"null"},
gm(a){return 0},
$iu:1,
$iF:1}
J.bK.prototype={$iA:1}
J.ar.prototype={
gm(a){return 0},
i(a){return String(a)}}
J.d0.prototype={}
J.b1.prototype={}
J.ai.prototype={
i(a){var s=a[$.i9()]
if(s==null)s=a[$.eX()]
if(s==null)return this.aV(a)
return"JavaScript function for "+J.ap(s)},
$iaL:1}
J.bj.prototype={
gm(a){return 0},
i(a){return String(a)}}
J.bk.prototype={
gm(a){return 0},
i(a){return String(a)}}
J.v.prototype={
u(a,b){A.H(a).c.a(b)
a.$flags&1&&A.aD(a,29)
a.push(b)},
Y(a,b,c){var s=A.H(a)
return new A.q(a,s.t(c).h("1(2)").a(b),s.h("@<1>").t(c).h("q<1,2>"))},
bo(a,b){var s,r=A.f2(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)this.q(r,s,A.e(a[s]))
return r.join(b)},
G(a,b){if(!(b>=0&&b<a.length))return A.c(a,b)
return a[b]},
gB(a){return a.length===0},
gM(a){return a.length!==0},
i(a){return A.f_(a,"[","]")},
gC(a){return new J.aF(a,a.length,A.H(a).h("aF<1>"))},
gm(a){return A.d2(a)},
gp(a){return a.length},
l(a,b){if(!(b>=0&&b<a.length))throw A.f(A.ds(a,b))
return a[b]},
q(a,b,c){A.H(a).c.a(c)
a.$flags&2&&A.aD(a)
if(!(b>=0&&b<a.length))throw A.f(A.ds(a,b))
a[b]=c},
$im:1,
$ii:1,
$in:1}
J.cF.prototype={
bz(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.d3(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.dA.prototype={}
J.aF.prototype={
gA(){var s=this.d
return s==null?this.$ti.c.a(s):s},
v(){var s,r=this,q=r.a,p=q.length
if(r.b!==p){q=A.cs(q)
throw A.f(q)}s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0},
$iR:1}
J.bJ.prototype={
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
throw A.f(A.d9(""+a+".round()"))},
aH(a,b,c){if(B.c.ag(b,c)>0)throw A.f(A.cq(b))
if(this.ag(a,b)<0)return b
if(this.ag(a,c)>0)return c
return a},
bx(a,b){var s,r,q,p,o
if(b<2||b>36)throw A.f(A.V(b,2,36,"radix",null))
s=a.toString(b)
r=s.length
q=r-1
if(!(q>=0))return A.c(s,q)
if(s.charCodeAt(q)!==41)return s
p=/^([\da-z]+)(?:\.([\da-z]+))?\(e\+(\d+)\)$/.exec(s)
if(p==null)A.a1(A.d9("Unexpected toString result: "+s))
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
N(a,b){return(a|0)===a?a/b|0:this.b9(a,b)},
b9(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.f(A.d9("Result of truncating division is "+A.e(s)+": "+A.e(a)+" ~/ "+b))},
k(a,b){var s
if(a>0)s=this.b8(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
b8(a,b){return b>31?0:a>>>b},
gD(a){return A.ba(t.o)},
$ir:1,
$ibf:1}
J.bi.prototype={
aQ(a){return-a},
gD(a){return A.ba(t.S)},
$iu:1,
$ib:1}
J.bI.prototype={
gD(a){return A.ba(t.i)},
$iu:1}
J.aM.prototype={
aT(a,b){var s=b.length
if(s>a.length)return!1
return b===a.substring(0,s)},
L(a,b,c){return a.substring(b,A.h9(b,c,a.length))},
aU(a,b){return this.L(a,b,null)},
by(a){var s,r,q,p=a.trim(),o=p.length
if(o===0)return p
if(0>=o)return A.c(p,0)
if(p.charCodeAt(0)===133){s=J.iP(p,1)
if(s===o)return""}else s=0
r=o-1
if(!(r>=0))return A.c(p,r)
q=p.charCodeAt(r)===133?J.iQ(p,r):o
if(s===0&&q===o)return p
return p.substring(s,q)},
E(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.f(B.B)
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
gD(a){return A.ba(t.N)},
gp(a){return a.length},
l(a,b){if(b>=a.length)throw A.f(A.ds(a,b))
return a[b]},
$iu:1,
$idH:1,
$ij:1}
A.bv.prototype={
gC(a){return new A.bC(J.ct(this.gO()),A.E(this).h("bC<1,2>"))},
gp(a){return J.Q(this.gO())},
gB(a){return J.io(this.gO())},
gM(a){return J.ip(this.gO())},
G(a,b){return A.E(this).y[1].a(J.ft(this.gO(),b))},
i(a){return J.ap(this.gO())}}
A.bC.prototype={
v(){return this.a.v()},
gA(){return this.$ti.y[1].a(this.a.gA())},
$iR:1}
A.aG.prototype={
gO(){return this.a}}
A.c5.prototype={$im:1}
A.aH.prototype={
af(a,b,c){return new A.aH(this.a,this.$ti.h("@<1,2>").t(b).t(c).h("aH<1,2,3,4>"))},
l(a,b){return this.$ti.h("4?").a(this.a.l(0,b))},
J(a,b){this.a.J(0,new A.dw(this,this.$ti.h("~(3,4)").a(b)))},
gK(){var s=this.$ti
return A.fA(this.a.gK(),s.c,s.y[2])},
gp(a){var s=this.a
return s.gp(s)},
gB(a){var s=this.a
return s.gB(s)}}
A.dw.prototype={
$2(a,b){var s=this.a.$ti
s.c.a(a)
s.y[1].a(b)
this.b.$2(s.y[2].a(a),s.y[3].a(b))},
$S(){return this.a.$ti.h("~(1,2)")}}
A.cL.prototype={
i(a){return"LateInitializationError: "+this.a}}
A.cy.prototype={
gp(a){return this.a.length},
l(a,b){var s=this.a
if(!(b>=0&&b<s.length))return A.c(s,b)
return s.charCodeAt(b)}}
A.dN.prototype={}
A.m.prototype={}
A.B.prototype={
gC(a){var s=this
return new A.aO(s,s.gp(s),A.E(s).h("aO<B.E>"))},
gB(a){return this.gp(this)===0},
bn(a){var s,r,q=this,p=q.gp(q)
for(s=0,r="";s<p;++s){r+=A.e(q.G(0,s))
if(p!==q.gp(q))throw A.f(A.aI(q))}return r.charCodeAt(0)==0?r:r}}
A.aO.prototype={
gA(){var s=this.d
return s==null?this.$ti.c.a(s):s},
v(){var s,r=this,q=r.a,p=J.cr(q),o=p.gp(q)
if(r.b!==o)throw A.f(A.aI(q))
s=r.c
if(s>=o){r.d=null
return!1}r.d=p.G(q,s);++r.c
return!0},
$iR:1}
A.aP.prototype={
gC(a){var s=this.a
return new A.bP(s.gC(s),this.b,A.E(this).h("bP<1,2>"))},
gp(a){var s=this.a
return s.gp(s)},
gB(a){var s=this.a
return s.gB(s)},
G(a,b){var s=this.a
return this.b.$1(s.G(s,b))}}
A.bF.prototype={$im:1}
A.bP.prototype={
v(){var s=this,r=s.b
if(r.v()){s.a=s.c.$1(r.gA())
return!0}s.a=null
return!1},
gA(){var s=this.a
return s==null?this.$ti.y[1].a(s):s},
$iR:1}
A.q.prototype={
gp(a){return J.Q(this.a)},
G(a,b){return this.b.$1(J.ft(this.a,b))}}
A.c2.prototype={
gC(a){return new A.c3(J.ct(this.a),this.b,this.$ti.h("c3<1>"))}}
A.c3.prototype={
v(){var s,r
for(s=this.a,r=this.b;s.v();)if(r.$1(s.gA()))return!0
return!1},
gA(){return this.a.gA()},
$iR:1}
A.T.prototype={}
A.c0.prototype={}
A.bu.prototype={}
A.cd.prototype={$r:"+bufPtr,docPtr(1,2)",$s:1}
A.bw.prototype={$r:"+end,start(1,2)",$s:2}
A.ce.prototype={$r:"+message,transfer(1,2)",$s:3}
A.ad.prototype={$r:"+message,type(1,2)",$s:4}
A.ae.prototype={$r:"+pageIndex,scrollPosition,uri(1,2,3)",$s:5}
A.cf.prototype={$r:"+pixelHeight,pixelWidth,pixels(1,2,3)",$s:6}
A.bD.prototype={
af(a,b,c){var s=A.E(this)
return A.fM(this,s.c,s.y[1],b,c)},
gB(a){return this.gp(this)===0},
i(a){return A.f3(this)},
$il:1}
A.aJ.prototype={
gp(a){return this.b.length},
gav(){var s=this.$keys
if(s==null){s=Object.keys(this.a)
this.$keys=s}return s},
bd(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
l(a,b){if(!this.bd(b))return null
return this.b[this.a[b]]},
J(a,b){var s,r,q,p
this.$ti.h("~(1,2)").a(b)
s=this.gav()
r=this.b
for(q=s.length,p=0;p<q;++p)b.$2(s[p],r[p])},
gK(){return new A.c6(this.gav(),this.$ti.h("c6<1>"))}}
A.c6.prototype={
gp(a){return this.a.length},
gB(a){return 0===this.a.length},
gM(a){return 0!==this.a.length},
gC(a){var s=this.a
return new A.c7(s,s.length,this.$ti.h("c7<1>"))}}
A.c7.prototype={
gA(){var s=this.d
return s==null?this.$ti.c.a(s):s},
v(){var s=this,r=s.c
if(r>=s.b){s.d=null
return!1}s.d=s.a[r]
s.c=r+1
return!0},
$iR:1}
A.bY.prototype={}
A.dP.prototype={
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
A.bU.prototype={
i(a){return"Null check operator used on a null value"}}
A.cI.prototype={
i(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.d8.prototype={
i(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.dG.prototype={
i(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.bG.prototype={}
A.ch.prototype={
i(a){var s,r=this.b
if(r!=null)return r
r=this.a
s=r!==null&&typeof r==="object"?r.stack:null
return this.b=s==null?"":s},
$iay:1}
A.aq.prototype={
i(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.i8(r==null?"unknown":r)+"'"},
$iaL:1,
gbC(){return this},
$C:"$1",
$R:1,
$D:null}
A.cw.prototype={$C:"$0",$R:0}
A.cx.prototype={$C:"$2",$R:2}
A.d6.prototype={}
A.d5.prototype={
i(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.i8(s)+"'"}}
A.bh.prototype={
n(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.bh))return!1
return this.$_target===b.$_target&&this.a===b.a},
gm(a){return(A.i4(this.a)^A.d2(this.$_target))>>>0},
i(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.d3(this.a)+"'")}}
A.d4.prototype={
i(a){return"RuntimeError: "+this.a}}
A.aj.prototype={
gp(a){return this.a},
gB(a){return this.a===0},
gK(){return new A.aN(this,A.E(this).h("aN<1>"))},
bb(a,b){A.E(this).h("l<1,2>").a(b).J(0,new A.dB(this))},
l(a,b){var s,r,q,p,o=null
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
q(a,b,c){var s,r,q=this,p=A.E(q)
p.c.a(b)
p.y[1].a(c)
if(typeof b=="string"){s=q.b
q.ao(s==null?q.b=q.ab():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.ao(r==null?q.c=q.ab():r,b,c)}else q.bm(b,c)},
bm(a,b){var s,r,q,p,o=this,n=A.E(o)
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
A.E(q).h("~(1,2)").a(b)
s=q.e
r=q.r
while(s!=null){b.$2(s.a,s.b)
if(r!==q.r)throw A.f(A.aI(q))
s=s.c}},
ao(a,b,c){var s,r=A.E(this)
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
a2(a,b){var s=this,r=A.E(s),q=new A.dE(r.c.a(a),r.y[1].a(b))
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
ai(a){return J.h(a)&1073741823},
aj(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.d(a[r].a,b))return r
return-1},
i(a){return A.f3(this)},
ab(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
$ifJ:1}
A.dB.prototype={
$2(a,b){var s=this.a,r=A.E(s)
s.q(0,r.c.a(a),r.y[1].a(b))},
$S(){return A.E(this.a).h("~(1,2)")}}
A.dE.prototype={}
A.aN.prototype={
gp(a){return this.a.a},
gB(a){return this.a.a===0},
gC(a){var s=this.a
return new A.bO(s,s.r,s.e,this.$ti.h("bO<1>"))}}
A.bO.prototype={
gA(){return this.d},
v(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.f(A.aI(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}},
$iR:1}
A.bM.prototype={
gp(a){return this.a.a},
gB(a){return this.a.a===0},
gC(a){var s=this.a
return new A.bN(s,s.r,s.e,this.$ti.h("bN<1,2>"))}}
A.bN.prototype={
gA(){var s=this.d
s.toString
return s},
v(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.f(A.aI(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.as(s.a,s.b,r.$ti.h("as<1,2>"))
r.c=s.c
return!0}},
$iR:1}
A.eR.prototype={
$1(a){return this.a(a)},
$S:4}
A.eS.prototype={
$2(a,b){return this.a(a,b)},
$S:9}
A.eT.prototype={
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
l=a?l+A.h6(o):l+A.e(o)}l+=")"
return l.charCodeAt(0)==0?l:l},
b1(){var s,r=this.$s
while($.eg.length<=r)B.d.u($.eg,null)
s=$.eg[r]
if(s==null){s=this.b_()
B.d.q($.eg,r,s)}return s},
b_(){var s,r,q,p=this.$r,o=p.indexOf("("),n=p.substring(1,o),m=p.substring(o),l=m==="()"?0:m.replace(/[^,]/g,"").length+1,k=t.K,j=J.fE(l,k)
for(s=0;s<l;++s)j[s]=s
if(n!==""){r=n.split(",")
s=r.length
for(q=l;s>0;){--q;--s
B.d.q(j,q,r[s])}}j=A.iS(j,!1,k)
j.$flags=3
return j}}
A.an.prototype={
aa(){return[this.a,this.b]},
n(a,b){if(b==null)return!1
return b instanceof A.an&&this.$s===b.$s&&J.d(this.a,b.a)&&J.d(this.b,b.b)},
gm(a){return A.y(this.$s,this.a,this.b,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)}}
A.b6.prototype={
aa(){return[this.a,this.b,this.c]},
n(a,b){var s=this
if(b==null)return!1
return b instanceof A.b6&&s.$s===b.$s&&J.d(s.a,b.a)&&J.d(s.b,b.b)&&J.d(s.c,b.c)},
gm(a){var s=this
return A.y(s.$s,s.a,s.b,s.c,B.a,B.a,B.a,B.a,B.a,B.a,B.a)}}
A.cH.prototype={
i(a){return"RegExp/"+this.a+"/"+this.b.flags},
gb4(){var s=this,r=s.c
if(r!=null)return r
r=s.b
return s.c=A.fH(s.a,r.multiline,!r.ignoreCase,r.unicode,r.dotAll,"g")},
$idH:1}
A.at.prototype={
gD(a){return B.ao},
aE(a,b,c){return c==null?new Uint8Array(a,b):new Uint8Array(a,b,c)},
$iu:1,
$iat:1}
A.aa.prototype={$iaa:1}
A.bS.prototype={
gae(a){if(((a.$flags|0)&2)!==0)return new A.em(a.buffer)
else return a.buffer},
b3(a,b,c,d){var s=A.V(b,0,c,d,null)
throw A.f(s)},
ar(a,b,c,d){if(b>>>0!==b||b>c)this.b3(a,b,c,d)}}
A.em.prototype={
aE(a,b,c){var s=A.fN(this.a,b,c)
s.$flags=3
return s}}
A.cM.prototype={
gD(a){return B.ap},
$iu:1}
A.N.prototype={
gp(a){return a.length},
$iY:1}
A.bQ.prototype={
l(a,b){A.aA(b,a,a.length)
return a[b]},
$im:1,
$ii:1,
$in:1}
A.bR.prototype={
q(a,b,c){A.a(c)
a.$flags&2&&A.aD(a)
A.aA(b,a,a.length)
a[b]=c},
aS(a,b,c,d,e){var s,r,q,p
t.bP.a(d)
a.$flags&2&&A.aD(a,5)
s=a.length
this.ar(a,b,s,"start")
this.ar(a,c,s,"end")
if(b>c)A.a1(A.V(b,0,c,null,null))
r=c-b
if(e<0)A.a1(A.aE(e,null))
q=d.length
if(q-e<r)A.a1(A.dO("Not enough elements"))
p=e!==0||q!==r?d.subarray(e,e+r):d
a.set(p,b)
return},
$im:1,
$ii:1,
$in:1}
A.bl.prototype={
gD(a){return B.aq},
$iu:1,
$ibl:1}
A.bm.prototype={
gD(a){return B.ar},
$iu:1,
$ibm:1}
A.cN.prototype={
gD(a){return B.as},
l(a,b){A.aA(b,a,a.length)
return a[b]},
$iu:1}
A.bn.prototype={
gD(a){return B.at},
l(a,b){A.aA(b,a,a.length)
return a[b]},
$iu:1,
$ibn:1}
A.cO.prototype={
gD(a){return B.au},
l(a,b){A.aA(b,a,a.length)
return a[b]},
$iu:1}
A.cP.prototype={
gD(a){return B.aw},
l(a,b){A.aA(b,a,a.length)
return a[b]},
$iu:1}
A.cQ.prototype={
gD(a){return B.ax},
l(a,b){A.aA(b,a,a.length)
return a[b]},
$iu:1}
A.bT.prototype={
gD(a){return B.ay},
gp(a){return a.length},
l(a,b){A.aA(b,a,a.length)
return a[b]},
$iu:1}
A.aQ.prototype={
gD(a){return B.az},
gp(a){return a.length},
l(a,b){A.aA(b,a,a.length)
return a[b]},
a1(a,b,c){return new Uint8Array(a.subarray(b,A.hA(b,c,a.length)))},
$iu:1,
$iaQ:1,
$iac:1}
A.c9.prototype={}
A.ca.prototype={}
A.cb.prototype={}
A.cc.prototype={}
A.a6.prototype={
h(a){return A.cm(v.typeUniverse,this,a)},
t(a){return A.hq(v.typeUniverse,this,a)}}
A.de.prototype={}
A.ek.prototype={
i(a){return A.a_(this.a,null)}}
A.dd.prototype={
i(a){return this.a}}
A.ci.prototype={$ial:1}
A.dU.prototype={
$1(a){var s=this.a,r=s.a
s.a=null
r.$0()},
$S:5}
A.dT.prototype={
$1(a){var s,r
this.a.a=t.M.a(a)
s=this.b
r=this.c
s.firstChild?s.removeChild(r):s.appendChild(r)},
$S:11}
A.dV.prototype={
$0(){this.a.$0()},
$S:1}
A.dW.prototype={
$0(){this.a.$0()},
$S:1}
A.ei.prototype={
aW(a,b){if(self.setTimeout!=null)this.b=self.setTimeout(A.eJ(new A.ej(this,b),0),a)
else throw A.f(A.d9("`setTimeout()` not found."))},
aG(){if(self.setTimeout!=null){var s=this.b
if(s==null)return
self.clearTimeout(s)
this.b=null}else throw A.f(A.d9("Canceling a timer."))}}
A.ej.prototype={
$0(){this.a.b=null
this.b.$0()},
$S:0}
A.da.prototype={
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
A.es.prototype={
$1(a){return this.a.$2(0,a)},
$S:12}
A.et.prototype={
$2(a,b){this.a.$2(1,new A.bG(a,t.l.a(b)))},
$S:13}
A.eG.prototype={
$2(a,b){this.a(A.a(a),b)},
$S:14}
A.W.prototype={
i(a){return A.e(this.a)},
$ix:1,
gT(){return this.b}}
A.dc.prototype={
aI(a,b){var s=this.a
if((s.a&30)!==0)throw A.f(A.dO("Future already completed"))
s.a5(A.jR(a,b))}}
A.c4.prototype={
ah(a){var s,r=this.$ti
r.h("1/?").a(a)
s=this.a
if((s.a&30)!==0)throw A.f(A.dO("Future already completed"))
s.a4(r.h("1/").a(a))},
bc(){return this.ah(null)}}
A.b2.prototype={
bp(a){if((this.c&15)!==6)return!0
return this.b.b.am(t.c0.a(this.d),a.a,t.y,t.K)},
bj(a){var s,r=this,q=r.e,p=null,o=t.z,n=t.K,m=a.a,l=r.b.b
if(t.U.b(q))p=l.bt(q,m,a.b,o,n,t.l)
else p=l.am(t.v.a(q),m,o,n)
try{o=r.$ti.h("2/").a(p)
return o}catch(s){if(t.b7.b(A.af(s))){if((r.c&1)!==0)throw A.f(A.aE("The error handler of Future.then must return a value of the returned future's type","onError"))
throw A.f(A.aE("The error handler of Future.catchError must return a value of the future's type","onError"))}else throw s}}}
A.D.prototype={
an(a,b,c){var s,r,q=this.$ti
q.t(c).h("1/(2)").a(a)
s=$.z
if(s===B.f){if(!t.U.b(b)&&!t.v.b(b))throw A.f(A.du(b,"onError",u.c))}else{c.h("@<0/>").t(q.c).h("1(2)").a(a)
b=A.kk(b,s)}r=new A.D(s,c.h("D<0>"))
this.a3(new A.b2(r,3,a,b,q.h("@<1>").t(c).h("b2<1,2>")))
return r},
aB(a,b,c){var s,r=this.$ti
r.t(c).h("1/(2)").a(a)
s=new A.D($.z,c.h("D<0>"))
this.a3(new A.b2(s,19,a,b,r.h("@<1>").t(c).h("b2<1,2>")))
return s},
b7(a){this.a=this.a&1|16
this.c=a},
U(a){this.a=a.a&30|this.a&1
this.c=a.c},
a3(a){var s,r=this,q=r.a
if(q<=3){a.a=t.F.a(r.c)
r.c=a}else{if((q&4)!==0){s=t._.a(r.c)
if((s.a&24)===0){s.a3(a)
return}r.U(s)}A.dq(null,null,r.b,t.M.a(new A.dZ(r,a)))}},
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
A.dq(null,null,m.b,t.M.a(new A.e3(l,m)))}},
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
A.b3(r,s)},
aZ(a){var s,r,q=this
if((a.a&16)!==0){s=q.b===a.b
s=!(s||s)}else s=!1
if(s)return
r=q.S()
q.U(a)
A.b3(q,r)},
R(a){var s=this.S()
this.b7(a)
A.b3(this,s)},
a4(a){var s=this.$ti
s.h("1/").a(a)
if(s.h("ah<1>").b(a)){this.aq(a)
return}this.aY(a)},
aY(a){var s=this
s.$ti.c.a(a)
s.a^=2
A.dq(null,null,s.b,t.M.a(new A.e0(s,a)))},
aq(a){A.e1(this.$ti.h("ah<1>").a(a),this,!1)
return},
a5(a){this.a^=2
A.dq(null,null,this.b,t.M.a(new A.e_(this,a)))},
bv(a,b){var s,r,q=this,p={},o=q.$ti
o.h("1/()?").a(b)
if((q.a&24)!==0){p=new A.D($.z,o)
p.a4(q)
return p}s=$.z
r=new A.D(s,o)
p.a=null
p.a=A.j6(a,new A.e9(q,r,s,o.h("1/()").a(b)))
q.an(new A.ea(p,q,r),new A.eb(p,r),t.P)
return r},
$iah:1}
A.dZ.prototype={
$0(){A.b3(this.a,this.b)},
$S:0}
A.e3.prototype={
$0(){A.b3(this.b,this.a.a)},
$S:0}
A.e2.prototype={
$0(){A.e1(this.a.a,this.b,!0)},
$S:0}
A.e0.prototype={
$0(){this.a.a7(this.b)},
$S:0}
A.e_.prototype={
$0(){this.a.R(this.b)},
$S:0}
A.e6.prototype={
$0(){var s,r,q,p,o,n,m,l,k=this,j=null
try{q=k.a.a
j=q.b.b.aN(t.bd.a(q.d),t.z)}catch(p){s=A.af(p)
r=A.bc(p)
if(k.c&&t.n.a(k.b.a.c).a===s){q=k.a
q.c=t.n.a(k.b.a.c)}else{q=s
o=r
if(o==null)o=A.dv(q)
n=k.a
n.c=new A.W(q,o)
q=n}q.b=!0
return}if(j instanceof A.D&&(j.a&24)!==0){if((j.a&16)!==0){q=k.a
q.c=t.n.a(j.c)
q.b=!0}return}if(j instanceof A.D){m=k.b.a
l=new A.D(m.b,m.$ti)
j.an(new A.e7(l,m),new A.e8(l),t.H)
q=k.a
q.c=l
q.b=!1}},
$S:0}
A.e7.prototype={
$1(a){this.a.aZ(this.b)},
$S:5}
A.e8.prototype={
$2(a,b){A.bx(a)
t.l.a(b)
this.a.R(new A.W(a,b))},
$S:6}
A.e5.prototype={
$0(){var s,r,q,p,o,n,m,l
try{q=this.a
p=q.a
o=p.$ti
n=o.c
m=n.a(this.b)
q.c=p.b.b.am(o.h("2/(1)").a(p.d),m,o.h("2/"),n)}catch(l){s=A.af(l)
r=A.bc(l)
q=s
p=r
if(p==null)p=A.dv(q)
o=this.a
o.c=new A.W(q,p)
o.b=!0}},
$S:0}
A.e4.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{s=t.n.a(l.a.a.c)
p=l.b
if(p.a.bp(s)&&p.a.e!=null){p.c=p.a.bj(s)
p.b=!1}}catch(o){r=A.af(o)
q=A.bc(o)
p=t.n.a(l.a.a.c)
if(p.a===r){n=l.b
n.c=p
p=n}else{p=r
n=q
if(n==null)n=A.dv(p)
m=l.b
m.c=new A.W(p,n)
p=m}p.b=!0}},
$S:0}
A.e9.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{q=l.b
p=q.$ti
o=p.h("1/").a(l.c.aN(l.d,l.a.$ti.h("1/")))
if(p.h("ah<1>").b(o))A.e1(o,q,!0)
else{n=q.S()
p.c.a(o)
q.a=8
q.c=o
A.b3(q,n)}}catch(m){s=A.af(m)
r=A.bc(m)
q=s
p=r
if(p==null)p=A.dv(q)
l.b.R(new A.W(q,p))}},
$S:0}
A.ea.prototype={
$1(a){var s
this.b.$ti.c.a(a)
s=this.a.a
if(s.b!=null){s.aG()
this.c.a7(a)}},
$S(){return this.b.$ti.h("F(1)")}}
A.eb.prototype={
$2(a,b){var s
A.bx(a)
t.l.a(b)
s=this.a.a
if(s.b!=null){s.aG()
this.b.R(new A.W(a,b))}},
$S:6}
A.db.prototype={}
A.dj.prototype={}
A.cn.prototype={$ihf:1}
A.di.prototype={
bu(a){var s,r,q
t.M.a(a)
try{if(B.f===$.z){a.$0()
return}A.hR(null,null,this,a,t.H)}catch(q){s=A.af(q)
r=A.bc(q)
A.fj(A.bx(s),t.l.a(r))}},
aF(a){return new A.eh(this,t.M.a(a))},
aN(a,b){b.h("0()").a(a)
if($.z===B.f)return a.$0()
return A.hR(null,null,this,a,b)},
am(a,b,c,d){c.h("@<0>").t(d).h("1(2)").a(a)
d.a(b)
if($.z===B.f)return a.$1(b)
return A.kn(null,null,this,a,b,c,d)},
bt(a,b,c,d,e,f){d.h("@<0>").t(e).t(f).h("1(2,3)").a(a)
e.a(b)
f.a(c)
if($.z===B.f)return a.$2(b,c)
return A.km(null,null,this,a,b,c,d,e,f)},
aL(a,b,c,d){return b.h("@<0>").t(c).t(d).h("1(2,3)").a(a)}}
A.eh.prototype={
$0(){return this.a.bu(this.b)},
$S:0}
A.eF.prototype={
$0(){A.iF(this.a,this.b)},
$S:0}
A.c8.prototype={
gC(a){var s=this,r=new A.b4(s,s.r,s.$ti.h("b4<1>"))
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
return q.ap(s==null?q.b=A.fa():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.ap(r==null?q.c=A.fa():r,b)}else return q.aX(b)},
aX(a){var s,r,q,p=this
p.$ti.c.a(a)
s=p.d
if(s==null)s=p.d=A.fa()
r=J.h(a)&1073741823
q=s[r]
if(q==null)s[r]=[p.ac(a)]
else{if(p.au(q,a)>=0)return!1
q.push(p.ac(a))}return!0},
ap(a,b){this.$ti.c.a(b)
if(t.L.a(a[b])!=null)return!1
a[b]=this.ac(b)
return!0},
ac(a){var s=this,r=new A.dh(s.$ti.c.a(a))
if(s.e==null)s.e=s.f=r
else s.f=s.f.b=r;++s.a
s.r=s.r+1&1073741823
return r},
au(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.d(a[r].a,b))return r
return-1}}
A.dh.prototype={}
A.b4.prototype={
gA(){var s=this.d
return s==null?this.$ti.c.a(s):s},
v(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.f(A.aI(q))
else if(r==null){s.d=null
return!1}else{s.d=s.$ti.h("1?").a(r.a)
s.c=r.b
return!0}},
$iR:1}
A.t.prototype={
gC(a){return new A.aO(a,this.gp(a),A.bd(a).h("aO<t.E>"))},
G(a,b){return this.l(a,b)},
gB(a){return this.gp(a)===0},
gM(a){return!this.gB(a)},
Y(a,b,c){var s=A.bd(a)
return new A.q(a,s.t(c).h("1(t.E)").a(b),s.h("@<t.E>").t(c).h("q<1,2>"))},
i(a){return A.f_(a,"[","]")},
$im:1,
$ii:1,
$in:1}
A.L.prototype={
af(a,b,c){var s=A.E(this)
return A.fM(this,s.h("L.K"),s.h("L.V"),b,c)},
J(a,b){var s,r,q,p=A.E(this)
p.h("~(L.K,L.V)").a(b)
for(s=this.gK(),s=s.gC(s),p=p.h("L.V");s.v();){r=s.gA()
q=this.l(0,r)
b.$2(r,q==null?p.a(q):q)}},
gp(a){var s=this.gK()
return s.gp(s)},
gB(a){var s=this.gK()
return s.gB(s)},
i(a){return A.f3(this)},
$il:1}
A.dF.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.e(a)
r.a=(r.a+=s)+": "
s=A.e(b)
r.a+=s},
$S:7}
A.bt.prototype={
gB(a){return this.a===0},
gM(a){return this.a!==0},
i(a){return A.f_(this,"{","}")},
G(a,b){var s,r,q,p=this
A.f6(b,"index")
s=A.jg(p,p.r,p.$ti.c)
for(r=b;s.v();){if(r===0){q=s.d
return q==null?s.$ti.c.a(q):q}--r}throw A.f(A.eZ(b,b-r,p,"index"))},
$im:1,
$ii:1}
A.cg.prototype={}
A.df.prototype={
l(a,b){var s,r=this.b
if(r==null)return this.c.l(0,b)
else if(typeof b!="string")return null
else{s=r[b]
return typeof s=="undefined"?this.b5(b):s}},
gp(a){return this.b==null?this.c.a:this.V().length},
gB(a){return this.gp(0)===0},
gK(){if(this.b==null){var s=this.c
return new A.aN(s,A.E(s).h("aN<1>"))}return new A.dg(this)},
J(a,b){var s,r,q,p,o=this
t.cQ.a(b)
if(o.b==null)return o.c.J(0,b)
s=o.V()
for(r=0;r<s.length;++r){q=s[r]
p=o.b[q]
if(typeof p=="undefined"){p=A.eu(o.a[q])
o.b[q]=p}b.$2(q,p)
if(s!==o.c)throw A.f(A.aI(o))}},
V(){var s=t.aL.a(this.c)
if(s==null)s=this.c=A.w(Object.keys(this.a),t.s)
return s},
b5(a){var s
if(!Object.prototype.hasOwnProperty.call(this.a,a))return null
s=A.eu(this.a[a])
return this.b[a]=s}}
A.dg.prototype={
gp(a){return this.a.gp(0)},
G(a,b){var s=this.a
if(s.b==null)s=s.gK().G(0,b)
else{s=s.V()
if(!(b>=0&&b<s.length))return A.c(s,b)
s=s[b]}return s},
gC(a){var s=this.a
if(s.b==null){s=s.gK()
s=s.gC(s)}else{s=s.V()
s=new J.aF(s,s.length,A.H(s).h("aF<1>"))}return s}}
A.cz.prototype={}
A.cB.prototype={}
A.bL.prototype={
i(a){var s=A.cC(this.a)
return(this.b!=null?"Converting object to an encodable object failed:":"Converting object did not return an encodable object:")+" "+s}}
A.cK.prototype={
i(a){return"Cyclic error in JSON stringify"}}
A.cJ.prototype={
bf(a,b){var s=A.k4(a,this.gbg().a)
return s},
bh(a,b){var s=A.jf(a,this.gbi().b,null)
return s},
gbi(){return B.J},
gbg(){return B.I}}
A.dD.prototype={}
A.dC.prototype={}
A.ee.prototype={
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
if(a==null?p==null:a===p)throw A.f(new A.cK(a,null))}B.d.u(s,a)},
Z(a){var s,r,q,p,o=this
if(o.aO(a))return
o.a6(a)
try{s=o.b.$1(a)
if(!o.aO(s)){q=A.fI(a,null,o.gaz())
throw A.f(q)}q=o.a
if(0>=q.length)return A.c(q,-1)
q.pop()}catch(p){r=A.af(p)
q=A.fI(a,r,o.gaz())
throw A.f(q)}},
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
s=J.cr(a)
if(s.gM(a)){this.Z(s.l(a,0))
for(r=1;r<s.gp(a);++r){q.a+=","
this.Z(s.l(a,r))}}q.a+="]"},
bB(a){var s,r,q,p,o,n,m=this,l={}
if(a.gB(a)){m.c.a+="{}"
return!0}s=a.gp(a)*2
r=A.f2(s,null,!1,t.X)
q=l.a=0
l.b=!0
a.J(0,new A.ef(l,r))
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
A.ef.prototype={
$2(a,b){var s,r
if(typeof a!="string")this.a.b=!1
s=this.b
r=this.a
B.d.q(s,r.a++,a)
B.d.q(s,r.a++,b)},
$S:7}
A.ed.prototype={
gaz(){var s=this.c.a
return s.charCodeAt(0)==0?s:s}}
A.dR.prototype={
be(a){var s,r,q,p=a.length,o=A.h9(0,null,p)
if(o===0)return new Uint8Array(0)
s=new Uint8Array(o*3)
r=new A.en(s)
if(r.b2(a,0,o)!==o){q=o-1
if(!(q>=0&&q<p))return A.c(a,q)
r.ad()}return B.i.a1(s,0,r.b)}}
A.en.prototype={
ad(){var s,r=this,q=r.c,p=r.b,o=r.b=p+1
q.$flags&2&&A.aD(q)
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
r.$flags&2&&A.aD(r)
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
r&2&&A.aD(s)
s[m]=n}else{m=n&64512
if(m===55296){if(k.b+4>q)break
m=o+1
if(!(m<p))return A.c(a,m)
if(k.ba(n,a.charCodeAt(m)))o=m}else if(m===56320){if(k.b+3>q)break
k.ad()}else if(n<=2047){m=k.b
l=m+1
if(l>=q)break
k.b=l
r&2&&A.aD(s)
if(!(m<q))return A.c(s,m)
s[m]=n>>>6|192
k.b=l+1
s[l]=n&63|128}else{m=k.b
if(m+2>=q)break
l=k.b=m+1
r&2&&A.aD(s)
if(!(m<q))return A.c(s,m)
s[m]=n>>>12|224
m=k.b=l+1
if(!(l<q))return A.c(s,l)
s[l]=n>>>6&63|128
k.b=m+1
if(!(m<q))return A.c(s,m)
s[m]=n&63|128}}}return o}}
A.dx.prototype={
$0(){var s=this
return A.a1(A.aE("("+s.a+", "+s.b+", "+s.c+", "+s.d+", "+s.e+", "+s.f+", "+s.r+", "+s.w+")",null))},
$S:8}
A.bE.prototype={
n(a,b){var s
if(b==null)return!1
s=!1
if(b instanceof A.bE)if(this.a===b.a)s=this.b===b.b
return s},
gm(a){return A.y(this.a,this.b,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){var s=this,r=A.fC(A.d1(s)),q=A.ag(A.h4(s)),p=A.ag(A.h0(s)),o=A.ag(A.h1(s)),n=A.ag(A.h3(s)),m=A.ag(A.h5(s)),l=A.dy(A.h2(s)),k=s.b,j=k===0?"":A.dy(k)
return r+"-"+q+"-"+p+" "+o+":"+n+":"+m+"."+l+j+"Z"},
bw(){var s=this,r=A.d1(s)>=-9999&&A.d1(s)<=9999?A.fC(A.d1(s)):A.iD(A.d1(s)),q=A.ag(A.h4(s)),p=A.ag(A.h0(s)),o=A.ag(A.h1(s)),n=A.ag(A.h3(s)),m=A.ag(A.h5(s)),l=A.dy(A.h2(s)),k=s.b,j=k===0?"":A.dy(k)
return r+"-"+q+"-"+p+"T"+o+":"+n+":"+m+"."+l+j+"Z"}}
A.aK.prototype={
n(a,b){if(b==null)return!1
return b instanceof A.aK&&this.a===b.a},
gm(a){return B.c.gm(this.a)},
i(a){var s,r,q,p,o,n=this.a,m=B.c.N(n,36e8),l=n%36e8
if(n<0){m=0-m
n=0-l
s="-"}else{n=l
s=""}r=B.c.N(n,6e7)
n%=6e7
q=r<10?"0":""
p=B.c.N(n,1e6)
o=p<10?"0":""
return s+m+":"+q+r+":"+o+p+"."+B.h.aK(B.c.i(n%1e6),6,"0")}}
A.dX.prototype={
i(a){return this.W()}}
A.x.prototype={
gT(){return A.iW(this)}}
A.cu.prototype={
i(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.cC(s)
return"Assertion failed"}}
A.al.prototype={}
A.a2.prototype={
ga9(){return"Invalid argument"+(!this.a?"(s)":"")},
ga8(){return""},
i(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+A.e(p),n=s.ga9()+q+o
if(!s.a)return n
return n+s.ga8()+": "+A.cC(s.gak())},
gak(){return this.b}}
A.ax.prototype={
gak(){return A.hu(this.b)},
ga9(){return"RangeError"},
ga8(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.e(q):""
else if(q==null)s=": Not greater than or equal to "+A.e(r)
else if(q>r)s=": Not in inclusive range "+A.e(r)+".."+A.e(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.e(r)
return s}}
A.cD.prototype={
gak(){return A.a(this.b)},
ga9(){return"RangeError"},
ga8(){if(A.a(this.b)<0)return": index must not be negative"
var s=this.f
if(s===0)return": no indices are valid"
return": index should be less than "+s},
$iax:1,
gp(a){return this.f}}
A.c1.prototype={
i(a){return"Unsupported operation: "+this.a}}
A.d7.prototype={
i(a){return"UnimplementedError: "+this.a}}
A.c_.prototype={
i(a){return"Bad state: "+this.a}}
A.cA.prototype={
i(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.cC(s)+"."}}
A.cR.prototype={
i(a){return"Out of Memory"},
gT(){return null},
$ix:1}
A.bZ.prototype={
i(a){return"Stack Overflow"},
gT(){return null},
$ix:1}
A.dY.prototype={
i(a){return"Exception: "+this.a}}
A.dz.prototype={
i(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException",q=this.b
if(typeof q=="string"){if(q.length>78)q=B.h.L(q,0,75)+"..."
return r+"\n"+q}else return r}}
A.i.prototype={
Y(a,b,c){var s=A.E(this)
return A.iT(this,s.t(c).h("1(i.E)").a(b),s.h("i.E"),c)},
gp(a){var s,r=this.gC(this)
for(s=0;r.v();)++s
return s},
gB(a){return!this.gC(this).v()},
gM(a){return!this.gB(this)},
G(a,b){var s,r
A.f6(b,"index")
s=this.gC(this)
for(r=b;s.v();){if(r===0)return s.gA();--r}throw A.f(A.eZ(b,b-r,this,"index"))},
i(a){return A.iL(this,"(",")")}}
A.as.prototype={
i(a){return"MapEntry("+A.e(this.a)+": "+A.e(this.b)+")"}}
A.F.prototype={
gm(a){return A.o.prototype.gm.call(this,0)},
i(a){return"null"}}
A.o.prototype={$io:1,
n(a,b){return this===b},
gm(a){return A.d2(this)},
i(a){return"Instance of '"+A.d3(this)+"'"},
gD(a){return A.kZ(this)},
toString(){return this.i(this)}}
A.dk.prototype={
i(a){return""},
$iay:1}
A.b0.prototype={
gp(a){return this.a.length},
i(a){var s=this.a
return s.charCodeAt(0)==0?s:s},
$ij4:1}
A.eO.prototype={
$1(a){return t.e.a(a)!=null},
$S:15}
A.ep.prototype={
sbq(a){this.a=A.ht(a)},
sbr(a){this.b=t.ak.a(a)}}
A.eV.prototype={
$1(a){var s,r,q,p,o=A.er(a).data
if(o==null||!t.m.b(o))return
A.er(o)
s=A.a(A.eq(o.id))
r=A.ao(o.op)
q=A.ao(o.json)
p=A.kb(o)
A.ev(this.a,new A.dS(s,r,t.f.a(B.p.bf(q,null)).af(0,t.N,t.z),p),this.b)},
$S:16}
A.ew.prototype={
$1(a){var s
A.a(a)
s=this.a.a
s.toString
s=A.kQ(s,this.b,a)
return A.p(["pageIndex",s.a,"text",s.b,"hasUnicodeErrors",s.c,"hasTextLayer",s.d],t.N,t.z)},
$S:2}
A.ex.prototype={
$1(a){var s,r,q
A.a(a)
s=this.a.a
s.toString
s=A.kO(s,this.b,a)
r=A.H(s)
q=r.h("q<1,l<j,@>>")
s=A.U(new A.q(s,r.h("l<j,@>(1)").a(A.k5()),q),q.h("B.E"))
return A.p(["pageIndex",a,"annotations",s],t.N,t.z)},
$S:2}
A.ey.prototype={
$1(a){var s,r,q=this
A.a(a)
r=q.a.a
r.toString
s=A.kP(r,q.b,a,q.c)
return A.kK(new A.dM(a,s),q.d)},
$S:2}
A.eB.prototype={
$0(){var s=this.a
if((s.a.a&30)===0)s.bc()},
$S:1}
A.eC.prototype={
$0(){return A.a1(A.bX("PDFium WASM module failed to initialise within 30 seconds inside the PDFium Worker. Ensure pdfium.js and pdfium.wasm are present at assets/pdfium/ relative to the app origin, alongside pdfium_worker.js (run `make fetch_wasm_assets`)."))},
$S:8}
A.dS.prototype={}
A.J.prototype={}
A.eL.prototype={
$1(a){var s=J.is(t.k.a(a),A.hI(),t.cg)
s=A.U(s,s.$ti.h("B.E"))
return s},
$S:17}
A.eM.prototype={
$1(a){var s,r,q,p
t.az.a(a)
s=this.a
r=a.f
if(r!=null){B.d.u(s,r)
q=s.length-1}else q=null
s=a.c
r=t.N
p=t.z
return A.p(["pageIndex",a.a,"objectIndex",a.b,"metadata",A.p(["width",s.a,"height",s.b,"horizontalDpi",s.c,"verticalDpi",s.d,"bitsPerPixel",s.e,"colorspace",s.f.b,"markedContentId",s.r],r,p),"bounds",A.eN(a.d),"filters",a.e,"bufIndex",q,"bitmapWidth",a.r,"bitmapHeight",a.w],r,p)},
$S:18}
A.eH.prototype={
$1(a){return t.h.a(B.i.gae(t.p.a(a)))},
$S:19}
A.eD.prototype={
$1(a){a.toString
return A.fN(t.h.a(a),0,null)},
$S:20}
A.cU.prototype={
W(){return"PdfError."+this.b}}
A.cV.prototype={
i(a){return"PdfExtractionException("+this.a.b+")"}}
A.cT.prototype={
i(a){return"PdfDate(raw: "+this.a+", value: "+A.e(this.b)+")"},
n(a,b){var s
if(b==null)return!1
if(this!==b)s=b instanceof A.cT&&this.a===b.a&&J.d(this.b,b.b)
else s=!0
return s},
gm(a){return A.y(this.a,this.b,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)}}
A.dL.prototype={
i(a){var s=this
return"PdfMetadata(title: "+A.e(s.a)+", author: "+A.e(s.b)+", subject: "+A.e(s.c)+", keywords: "+A.e(s.d)+", creator: "+A.e(s.e)+", producer: "+A.e(s.f)+", creationDate: "+A.e(s.r)+", modDate: "+A.e(s.w)+")"}}
A.bq.prototype={
i(a){var s=this,r=s.b
if(r.length>40)r=B.h.L(r,0,40)+"\u2026"
return"PdfPageText(pageIndex: "+s.a+", hasTextLayer: "+s.d+", hasUnicodeErrors: "+s.c+", text: "+r+")"},
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.bq&&r.a===b.a&&r.b===b.b&&r.c===b.c&&r.d===b.d
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,B.a,B.a,B.a,B.a,B.a,B.a,B.a)}}
A.M.prototype={
W(){return"PdfAnnotationType."+this.b}}
A.cS.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.cS&&r.a===b.a&&r.b===b.b&&r.c===b.c&&r.d===b.d
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
A.cZ.prototype={
n(a,b){var s
if(b==null)return!1
if(this!==b)s=b instanceof A.cZ&&J.d(this.a,b.a)&&this.b===b.b
else s=!0
return s},
gm(a){return A.y(this.a,this.b,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){return"PdfPopupAnnotation(rect: "+A.e(this.a)+", flags: "+this.b+")"}}
A.G.prototype={}
A.aZ.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aZ&&r.a===b.a&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a,B.a)},
i(a){var s=this
return"PdfTextAnnotation(pageIndex: "+s.a+", contents: "+A.e(s.b)+", author: "+A.e(s.c)+", rect: "+A.e(s.d)+", color: "+A.e(s.e)+", modifiedDate: "+A.e(s.f)+", flags: "+s.r+", popup: "+A.e(s.w)+")"}}
A.aR.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aR&&r.a===b.a&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a,B.a)},
i(a){var s=this
return"PdfFreeTextAnnotation(pageIndex: "+s.a+", contents: "+A.e(s.b)+", author: "+A.e(s.c)+", rect: "+A.e(s.d)+", color: "+A.e(s.e)+", modifiedDate: "+A.e(s.f)+", flags: "+s.r+", popup: "+A.e(s.w)+")"}}
A.aV.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aV&&r.a===b.a&&r.x===b.x&&A.dn(r.y,b.y,t.u)&&r.z==b.z&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,A.bo(s.y),s.z,s.b,s.c,s.d,s.e,s.f,s.r,s.w)},
i(a){var s=this
return"PdfMarkupAnnotation(pageIndex: "+s.a+", subtype: "+s.x.i(0)+", quadPoints: "+s.y.length+" quads, markedText: "+A.e(s.z)+", contents: "+A.e(s.b)+", author: "+A.e(s.c)+", color: "+A.e(s.e)+", flags: "+s.r+")"}}
A.aX.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aX&&r.a===b.a&&r.x===b.x&&J.d(r.y,b.y)&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,s.y,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a)},
i(a){var s=this
return"PdfShapeAnnotation(pageIndex: "+s.a+", subtype: "+s.x.i(0)+", interiorColor: "+A.e(s.y)+", rect: "+A.e(s.d)+", color: "+A.e(s.e)+", flags: "+s.r+")"}}
A.aT.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aT&&r.a===b.a&&r.x.n(0,b.x)&&r.y.n(0,b.y)&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,s.y,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a)},
i(a){var s=this
return"PdfLineAnnotation(pageIndex: "+s.a+", lineStart: "+s.x.i(0)+", lineEnd: "+s.y.i(0)+", color: "+A.e(s.e)+", flags: "+s.r+")"}}
A.aS.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aS&&r.a===b.a&&A.iV(r.x,b.x)&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this,r=s.x,q=A.H(r)
return A.y(s.a,A.bo(new A.q(r,q.h("o?(1)").a(A.kG()),q.h("q<1,o?>"))),s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a)},
i(a){var s=this
return"PdfInkAnnotation(pageIndex: "+s.a+", strokes: "+s.x.length+", color: "+A.e(s.e)+", flags: "+s.r+")"}}
A.aW.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aW&&r.a===b.a&&r.x===b.x&&A.dn(r.y,b.y,t.w)&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,A.bo(s.y),s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a)},
i(a){var s=this
return"PdfPolygonAnnotation(pageIndex: "+s.a+", subtype: "+s.x.i(0)+", vertices: "+s.y.length+", color: "+A.e(s.e)+", flags: "+s.r+")"}}
A.aU.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aU&&r.a===b.a&&r.x==b.x&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a)},
i(a){var s=this
return"PdfLinkAnnotation(pageIndex: "+s.a+", uri: "+A.e(s.x)+", rect: "+A.e(s.d)+", flags: "+s.r+")"}}
A.aY.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aY&&r.a===b.a&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a,B.a)},
i(a){var s=this
return"PdfStampAnnotation(pageIndex: "+s.a+", contents: "+A.e(s.b)+", rect: "+A.e(s.d)+", flags: "+s.r+")"}}
A.b_.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.b_&&r.a===b.a&&r.x===b.x&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&J.d(r.e,b.e)&&J.d(r.f,b.f)&&r.r===b.r&&J.d(r.w,b.w)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.x,s.b,s.c,s.d,s.e,s.f,s.r,s.w,B.a,B.a)},
i(a){return"PdfUnknownAnnotation(pageIndex: "+this.a+", rawSubtype: "+this.x+", flags: "+this.r+")"}}
A.aw.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.aw&&r.a===b.a&&r.b==b.b&&r.c==b.c&&J.d(r.d,b.d)&&A.dn(r.e,b.e,t.b)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,A.bo(s.e),B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){var s=this
return"PdfTocEntry(title: "+s.a+", pageIndex: "+A.e(s.b)+", uri: "+A.e(s.c)+", scrollPosition: "+A.e(s.d)+", children: "+s.e.length+")"}}
A.X.prototype={
W(){return"PdfColorspace."+this.b}}
A.cX.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.cX&&r.a===b.a&&r.b===b.b&&r.c===b.c&&r.d===b.d&&r.e===b.e&&r.f===b.f&&r.r===b.r
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,s.e,s.f,s.r,B.a,B.a,B.a,B.a)},
i(a){var s=this
return"PdfImageMetadata(width: "+s.a+", height: "+s.b+", horizontalDpi: "+A.e(s.c)+", verticalDpi: "+A.e(s.d)+", bitsPerPixel: "+s.e+", colorspace: "+s.f.i(0)+", markedContentId: "+s.r+")"}}
A.au.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.au&&r.a===b.a&&r.b===b.b&&r.c.n(0,b.c)&&r.d.n(0,b.d)&&A.dn(r.e,b.e,t.N)&&r.r==b.r&&r.w==b.w
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,s.d,A.bo(s.e),s.r,s.w,B.a,B.a,B.a,B.a)},
i(a){var s=this,r=s.c.i(0),q=s.d.i(0),p=A.e(s.e),o=s.f
o=o!=null?""+o.length+" bytes":"null"
return"PdfImage(pageIndex: "+s.a+", objectIndex: "+s.b+", metadata: "+r+", bounds: "+q+", filters: "+p+", bitmapWidth: "+A.e(s.r)+", bitmapHeight: "+A.e(s.w)+", bgra: "+o+")"}}
A.cW.prototype={
n(a,b){var s
if(b==null)return!1
if(this!==b)s=b instanceof A.cW&&this.b===b.b&&this.c===b.c
else s=!0
return s},
gm(a){return A.y(this.b,this.c,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){return"PdfImageBitmap(width: "+this.b+", height: "+this.c+", bgra: "+this.a.length+" bytes)"}}
A.dM.prototype={
i(a){return"PdfPageImages(pageIndex: "+this.a+", images: "+this.b.length+")"}}
A.bV.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.bV&&r.a===b.a&&r.b===b.b&&r.c===b.c&&A.dn(r.d,b.d,t.O)
else s=!0
return s},
gm(a){var s=this
return A.y(s.a,s.b,s.c,A.bo(s.d),B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){var s=this
return"PdfSearchMatch(pageIndex: "+s.a+", charIndex: "+s.b+", charCount: "+s.c+", rects: "+s.d.length+")"}}
A.d_.prototype={
W(){return"PdfThumbnailSource."+this.b}}
A.bW.prototype={
n(a,b){var s,r=this
if(b==null)return!1
if(r!==b)s=b instanceof A.bW&&r.b===b.b&&r.c===b.c&&r.d===b.d
else s=!0
return s},
gm(a){return A.y(this.b,this.c,this.d,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)},
i(a){var s=this
return"PdfThumbnail(width: "+s.b+", height: "+s.c+", source: "+s.d.i(0)+", bgra: "+s.a.length+" bytes)"}}
A.dI.prototype={
i(a){var s=new A.dJ()
return"PdfDocumentInfo(fileVersion: "+A.e(this.a)+", permanentId: "+A.e(s.$1(this.b))+", changingId: "+A.e(s.$1(this.c))+")"}}
A.dJ.prototype={
$1(a){var s
if(a==null)s=null
else{s=A.bd(a)
s=new A.q(a,s.h("j(t.E)").a(new A.dK()),s.h("q<t.E,j>")).bn(0)}return s},
$S:21}
A.dK.prototype={
$1(a){return B.h.aK(B.c.bx(A.a(a),16),2,"0")},
$S:22}
A.br.prototype={
i(a){return"PdfiumException: "+this.a}}
A.cY.prototype={
i(a){return"PdfPageSize(widthPt: "+A.e(this.a)+", heightPt: "+A.e(this.b)+")"},
n(a,b){var s
if(b==null)return!1
if(this!==b)s=b instanceof A.cY&&b.a===this.a&&b.b===this.b
else s=!0
return s},
gm(a){return A.y(this.a,this.b,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a,B.a)}};(function aliases(){var s=J.ar.prototype
s.aV=s.i})();(function installTearOffs(){var s=hunkHelpers._static_1,r=hunkHelpers._static_0
s(A,"ky","jb",3)
s(A,"kz","jc",3)
s(A,"kA","jd",3)
r(A,"hX","kr",0)
s(A,"kF","jG",4)
s(A,"kG","bo",23)
s(A,"k7","eN",24)
s(A,"hI","kL",25)
s(A,"k6","kM",26)
s(A,"hJ","kN",27)
s(A,"k5","kJ",28)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.o,null)
q(A.o,[A.f0,J.cE,A.bY,J.aF,A.i,A.bC,A.L,A.aq,A.x,A.t,A.dN,A.aO,A.bP,A.c3,A.T,A.c0,A.Z,A.bD,A.c7,A.dP,A.dG,A.bG,A.ch,A.dE,A.bO,A.bN,A.cH,A.em,A.a6,A.de,A.ek,A.ei,A.da,A.W,A.dc,A.b2,A.D,A.db,A.dj,A.cn,A.bt,A.dh,A.b4,A.cz,A.cB,A.ee,A.en,A.bE,A.aK,A.dX,A.cR,A.bZ,A.dY,A.dz,A.as,A.F,A.dk,A.b0,A.ep,A.dS,A.J,A.cV,A.cT,A.dL,A.bq,A.cS,A.a5,A.C,A.av,A.cZ,A.G,A.aw,A.cX,A.au,A.cW,A.dM,A.bV,A.bW,A.dI,A.br,A.cY])
q(J.cE,[J.cG,J.bH,J.bK,J.bj,J.bk,J.bJ,J.aM])
q(J.bK,[J.ar,J.v,A.at,A.bS])
q(J.ar,[J.d0,J.b1,J.ai])
r(J.cF,A.bY)
r(J.dA,J.v)
q(J.bJ,[J.bi,J.bI])
q(A.i,[A.bv,A.m,A.aP,A.c2,A.c6])
r(A.aG,A.bv)
r(A.c5,A.aG)
q(A.L,[A.aH,A.aj,A.df])
q(A.aq,[A.cx,A.cw,A.d6,A.eR,A.eT,A.dU,A.dT,A.es,A.e7,A.ea,A.eO,A.eV,A.ew,A.ex,A.ey,A.eL,A.eM,A.eH,A.eD,A.dJ,A.dK])
q(A.cx,[A.dw,A.dB,A.eS,A.et,A.eG,A.e8,A.eb,A.dF,A.ef])
q(A.x,[A.cL,A.al,A.cI,A.d8,A.d4,A.dd,A.bL,A.cu,A.a2,A.c1,A.d7,A.c_,A.cA])
r(A.bu,A.t)
r(A.cy,A.bu)
q(A.m,[A.B,A.aN,A.bM])
r(A.bF,A.aP)
q(A.B,[A.q,A.dg])
q(A.Z,[A.an,A.b6])
q(A.an,[A.cd,A.bw,A.ce,A.ad])
q(A.b6,[A.ae,A.cf])
r(A.aJ,A.bD)
r(A.bU,A.al)
q(A.d6,[A.d5,A.bh])
r(A.aa,A.at)
q(A.bS,[A.cM,A.N])
q(A.N,[A.c9,A.cb])
r(A.ca,A.c9)
r(A.bQ,A.ca)
r(A.cc,A.cb)
r(A.bR,A.cc)
q(A.bQ,[A.bl,A.bm])
q(A.bR,[A.cN,A.bn,A.cO,A.cP,A.cQ,A.bT,A.aQ])
r(A.ci,A.dd)
q(A.cw,[A.dV,A.dW,A.ej,A.dZ,A.e3,A.e2,A.e0,A.e_,A.e6,A.e5,A.e4,A.e9,A.eh,A.eF,A.dx,A.eB,A.eC])
r(A.c4,A.dc)
r(A.di,A.cn)
r(A.cg,A.bt)
r(A.c8,A.cg)
r(A.cK,A.bL)
r(A.cJ,A.cz)
q(A.cB,[A.dD,A.dC,A.dR])
r(A.ed,A.ee)
q(A.a2,[A.ax,A.cD])
q(A.dX,[A.cU,A.M,A.X,A.d_])
q(A.G,[A.aZ,A.aR,A.aV,A.aX,A.aT,A.aS,A.aW,A.aU,A.aY,A.b_])
s(A.bu,A.c0)
s(A.c9,A.t)
s(A.ca,A.T)
s(A.cb,A.t)
s(A.cc,A.T)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{b:"int",r:"double",bf:"num",j:"String",b9:"bool",F:"Null",n:"List",o:"Object",l:"Map",A:"JSObject"},mangledNames:{},types:["~()","F()","l<j,@>(b)","~(~())","@(@)","F(@)","F(o,ay)","~(o?,o?)","0&()","@(@,j)","@(j)","F(~())","~(@)","F(@,ay)","~(b,@)","b9(G?)","F(A)","n<l<j,@>>(n<C>)","l<j,@>(au)","aa(ac)","ac(o?)","j?(ac?)","j(b)","b(i<o?>)","l<j,@>(a5)","l<j,@>(C)","l<j,@>(av)","l<j,@>(aw)","l<j,@>(G)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"2;bufPtr,docPtr":(a,b)=>c=>c instanceof A.cd&&a.b(c.a)&&b.b(c.b),"2;end,start":(a,b)=>c=>c instanceof A.bw&&a.b(c.a)&&b.b(c.b),"2;message,transfer":(a,b)=>c=>c instanceof A.ce&&a.b(c.a)&&b.b(c.b),"2;message,type":(a,b)=>c=>c instanceof A.ad&&a.b(c.a)&&b.b(c.b),"3;pageIndex,scrollPosition,uri":(a,b,c)=>d=>d instanceof A.ae&&a.b(d.a)&&b.b(d.b)&&c.b(d.c),"3;pixelHeight,pixelWidth,pixels":(a,b,c)=>d=>d instanceof A.cf&&a.b(d.a)&&b.b(d.b)&&c.b(d.c)}}
A.ju(v.typeUniverse,JSON.parse('{"d0":"ar","b1":"ar","ai":"ar","lh":"at","v":{"n":["1"],"m":["1"],"A":[],"i":["1"]},"cG":{"b9":[],"u":[]},"bH":{"F":[],"u":[]},"bK":{"A":[]},"ar":{"A":[]},"cF":{"bY":[]},"dA":{"v":["1"],"n":["1"],"m":["1"],"A":[],"i":["1"]},"aF":{"R":["1"]},"bJ":{"r":[],"bf":[]},"bi":{"r":[],"b":[],"bf":[],"u":[]},"bI":{"r":[],"bf":[],"u":[]},"aM":{"j":[],"dH":[],"u":[]},"bv":{"i":["2"]},"bC":{"R":["2"]},"aG":{"bv":["1","2"],"i":["2"],"i.E":"2"},"c5":{"aG":["1","2"],"bv":["1","2"],"m":["2"],"i":["2"],"i.E":"2"},"aH":{"L":["3","4"],"l":["3","4"],"L.K":"3","L.V":"4"},"cL":{"x":[]},"cy":{"t":["b"],"c0":["b"],"n":["b"],"m":["b"],"i":["b"],"t.E":"b"},"m":{"i":["1"]},"B":{"m":["1"],"i":["1"]},"aO":{"R":["1"]},"aP":{"i":["2"],"i.E":"2"},"bF":{"aP":["1","2"],"m":["2"],"i":["2"],"i.E":"2"},"bP":{"R":["2"]},"q":{"B":["2"],"m":["2"],"i":["2"],"B.E":"2","i.E":"2"},"c2":{"i":["1"],"i.E":"1"},"c3":{"R":["1"]},"bu":{"t":["1"],"c0":["1"],"n":["1"],"m":["1"],"i":["1"]},"cd":{"an":[],"Z":[]},"bw":{"an":[],"Z":[]},"ce":{"an":[],"Z":[]},"ad":{"an":[],"Z":[]},"ae":{"b6":[],"Z":[]},"cf":{"b6":[],"Z":[]},"bD":{"l":["1","2"]},"aJ":{"bD":["1","2"],"l":["1","2"]},"c6":{"i":["1"],"i.E":"1"},"c7":{"R":["1"]},"bU":{"al":[],"x":[]},"cI":{"x":[]},"d8":{"x":[]},"ch":{"ay":[]},"aq":{"aL":[]},"cw":{"aL":[]},"cx":{"aL":[]},"d6":{"aL":[]},"d5":{"aL":[]},"bh":{"aL":[]},"d4":{"x":[]},"aj":{"L":["1","2"],"fJ":["1","2"],"l":["1","2"],"L.K":"1","L.V":"2"},"aN":{"m":["1"],"i":["1"],"i.E":"1"},"bO":{"R":["1"]},"bM":{"m":["as<1,2>"],"i":["as<1,2>"],"i.E":"as<1,2>"},"bN":{"R":["as<1,2>"]},"an":{"Z":[]},"b6":{"Z":[]},"cH":{"dH":[]},"aa":{"at":[],"A":[],"u":[]},"bl":{"t":["r"],"N":["r"],"n":["r"],"Y":["r"],"m":["r"],"A":[],"i":["r"],"T":["r"],"u":[],"t.E":"r"},"bm":{"t":["r"],"N":["r"],"n":["r"],"Y":["r"],"m":["r"],"A":[],"i":["r"],"T":["r"],"u":[],"t.E":"r"},"bn":{"t":["b"],"N":["b"],"n":["b"],"Y":["b"],"m":["b"],"A":[],"i":["b"],"T":["b"],"u":[],"t.E":"b"},"aQ":{"ac":[],"t":["b"],"N":["b"],"n":["b"],"Y":["b"],"m":["b"],"A":[],"i":["b"],"T":["b"],"u":[],"t.E":"b"},"at":{"A":[],"u":[]},"bS":{"A":[]},"cM":{"A":[],"u":[]},"N":{"Y":["1"],"A":[]},"bQ":{"t":["r"],"N":["r"],"n":["r"],"Y":["r"],"m":["r"],"A":[],"i":["r"],"T":["r"]},"bR":{"t":["b"],"N":["b"],"n":["b"],"Y":["b"],"m":["b"],"A":[],"i":["b"],"T":["b"]},"cN":{"t":["b"],"N":["b"],"n":["b"],"Y":["b"],"m":["b"],"A":[],"i":["b"],"T":["b"],"u":[],"t.E":"b"},"cO":{"t":["b"],"N":["b"],"n":["b"],"Y":["b"],"m":["b"],"A":[],"i":["b"],"T":["b"],"u":[],"t.E":"b"},"cP":{"t":["b"],"N":["b"],"n":["b"],"Y":["b"],"m":["b"],"A":[],"i":["b"],"T":["b"],"u":[],"t.E":"b"},"cQ":{"t":["b"],"N":["b"],"n":["b"],"Y":["b"],"m":["b"],"A":[],"i":["b"],"T":["b"],"u":[],"t.E":"b"},"bT":{"t":["b"],"N":["b"],"n":["b"],"Y":["b"],"m":["b"],"A":[],"i":["b"],"T":["b"],"u":[],"t.E":"b"},"dd":{"x":[]},"ci":{"al":[],"x":[]},"W":{"x":[]},"c4":{"dc":["1"]},"D":{"ah":["1"]},"cn":{"hf":[]},"di":{"cn":[],"hf":[]},"c8":{"cg":["1"],"bt":["1"],"m":["1"],"i":["1"]},"b4":{"R":["1"]},"t":{"n":["1"],"m":["1"],"i":["1"]},"L":{"l":["1","2"]},"bt":{"m":["1"],"i":["1"]},"cg":{"bt":["1"],"m":["1"],"i":["1"]},"df":{"L":["j","@"],"l":["j","@"],"L.K":"j","L.V":"@"},"dg":{"B":["j"],"m":["j"],"i":["j"],"B.E":"j","i.E":"j"},"bL":{"x":[]},"cK":{"x":[]},"cJ":{"cz":["o?","j"]},"r":{"bf":[]},"b":{"bf":[]},"n":{"m":["1"],"i":["1"]},"j":{"dH":[]},"cu":{"x":[]},"al":{"x":[]},"a2":{"x":[]},"ax":{"x":[]},"cD":{"ax":[],"x":[]},"c1":{"x":[]},"d7":{"x":[]},"c_":{"x":[]},"cA":{"x":[]},"cR":{"x":[]},"bZ":{"x":[]},"dk":{"ay":[]},"b0":{"j4":[]},"aZ":{"G":[]},"aR":{"G":[]},"aV":{"G":[]},"aX":{"G":[]},"aT":{"G":[]},"aS":{"G":[]},"aW":{"G":[]},"aU":{"G":[]},"aY":{"G":[]},"b_":{"G":[]},"iK":{"n":["b"],"m":["b"],"i":["b"]},"ac":{"n":["b"],"m":["b"],"i":["b"]},"j9":{"n":["b"],"m":["b"],"i":["b"]},"iI":{"n":["b"],"m":["b"],"i":["b"]},"j7":{"n":["b"],"m":["b"],"i":["b"]},"iJ":{"n":["b"],"m":["b"],"i":["b"]},"j8":{"n":["b"],"m":["b"],"i":["b"]},"iG":{"n":["r"],"m":["r"],"i":["r"]},"iH":{"n":["r"],"m":["r"],"i":["r"]}}'))
A.jt(v.typeUniverse,JSON.parse('{"bu":1,"N":1,"cB":2}'))
var u={c:"Error handler must accept one Object or one Object and a StackTrace as arguments, and return a value of the returned future's type"}
var t=(function rtii(){var s=A.dt
return{n:s("W"),R:s("aJ<j,@>"),x:s("aK"),V:s("m<@>"),C:s("x"),Y:s("aL"),r:s("i<@>"),bP:s("i<b>"),J:s("i<o?>"),B:s("v<n<C>>"),bG:s("v<l<j,@>>"),W:s("v<au>"),Q:s("v<C>"),q:s("v<av>"),cN:s("v<a5>"),c:s("v<bV>"),a9:s("v<aw>"),s:s("v<j>"),a:s("v<ac>"),ce:s("v<@>"),t:s("v<b>"),cm:s("v<o?>"),T:s("bH"),m:s("A"),g:s("ai"),da:s("Y<@>"),k:s("n<C>"),j:s("n<@>"),cg:s("l<j,@>"),f:s("l<@,@>"),h:s("aa"),E:s("bl"),bi:s("bm"),A:s("bn"),Z:s("aQ"),P:s("F"),K:s("o"),d:s("G"),az:s("au"),w:s("C"),u:s("av"),O:s("a5"),b:s("aw"),G:s("ax"),cY:s("li"),cD:s("+()"),bq:s("+bufPtr,docPtr(b,b)"),l:s("ay"),N:s("j"),bW:s("u"),b7:s("al"),p:s("ac"),cr:s("b1"),aY:s("c4<~>"),_:s("D<@>"),D:s("D<~>"),y:s("b9"),c0:s("b9(o)"),i:s("r"),z:s("@"),bd:s("@()"),v:s("@(o)"),U:s("@(o,ay)"),S:s("b"),ak:s("ah<A>?"),bc:s("ah<F>?"),aQ:s("A?"),aL:s("n<@>?"),X:s("o?"),e:s("G?"),aD:s("j?"),F:s("b2<@,@>?"),L:s("dh?"),cG:s("b9?"),I:s("r?"),a3:s("b?"),ae:s("bf?"),o:s("bf"),H:s("~"),M:s("~()"),cQ:s("~(j,@)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.F=J.cE.prototype
B.d=J.v.prototype
B.c=J.bi.prototype
B.b=J.bJ.prototype
B.h=J.aM.prototype
B.G=J.ai.prototype
B.H=J.bK.prototype
B.i=A.aQ.prototype
B.u=J.d0.prototype
B.m=J.b1.prototype
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

B.p=new A.cJ()
B.B=new A.cR()
B.a=new A.dN()
B.C=new A.dR()
B.f=new A.di()
B.D=new A.dk()
B.j=new A.aK(0)
B.E=new A.aK(3e7)
B.I=new A.dC(null)
B.J=new A.dD(null)
B.N=s([],t.B)
B.M=s([],A.dt("v<G>"))
B.K=s([],t.W)
B.q=s([],t.Q)
B.O=s([],t.q)
B.k=s([],t.c)
B.L=s([],t.s)
B.e=s([],t.a)
B.T={thumbnail:0}
B.P=new A.aJ(B.T,[null],t.R)
B.S={}
B.r=new A.aJ(B.S,[],t.R)
B.R={bitmap:0}
B.Q=new A.aJ(B.R,[null],t.R)
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
B.l=new A.cU(0,"invalidDocument")
B.ak=new A.cU(1,"passwordRequired")
B.al=new A.a5(0,0,0,0)
B.am=new A.d_(0,"embedded")
B.an=new A.d_(1,"rendered")
B.ao=A.a8("ld")
B.ap=A.a8("le")
B.aq=A.a8("iG")
B.ar=A.a8("iH")
B.as=A.a8("iI")
B.at=A.a8("iJ")
B.au=A.a8("iK")
B.av=A.a8("o")
B.aw=A.a8("j7")
B.ax=A.a8("j8")
B.ay=A.a8("j9")
B.az=A.a8("ac")})();(function staticFields(){$.ec=null
$.a0=A.w([],A.dt("v<o>"))
$.h_=null
$.fy=null
$.fx=null
$.i3=null
$.hW=null
$.i6=null
$.eK=null
$.eU=null
$.fo=null
$.eg=A.w([],A.dt("v<n<o>?>"))
$.by=null
$.co=null
$.cp=null
$.fh=!1
$.z=B.f})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"lg","i9",()=>A.i2("_$dart_dartClosure"))
s($,"lf","eX",()=>A.i2("_$dart_dartClosure_dartJSInterop"))
s($,"lw","il",()=>A.w([new J.cF()],A.dt("v<bY>")))
s($,"lk","ia",()=>A.am(A.dQ({
toString:function(){return"$receiver$"}})))
s($,"ll","ib",()=>A.am(A.dQ({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"lm","ic",()=>A.am(A.dQ(null)))
s($,"ln","id",()=>A.am(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"lq","ih",()=>A.am(A.dQ(void 0)))
s($,"lr","ii",()=>A.am(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"lp","ig",()=>A.am(A.hc(null)))
s($,"lo","ie",()=>A.am(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"lt","ik",()=>A.am(A.hc(void 0)))
s($,"ls","ij",()=>A.am(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"lu","fr",()=>A.ja())
s($,"lv","a9",()=>A.i4(B.av))})();(function nativeSupport(){!function(){var s=function(a){var m={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({SharedArrayBuffer:A.at,ArrayBuffer:A.aa,ArrayBufferView:A.bS,DataView:A.cM,Float32Array:A.bl,Float64Array:A.bm,Int16Array:A.cN,Int32Array:A.bn,Int8Array:A.cO,Uint16Array:A.cP,Uint32Array:A.cQ,Uint8ClampedArray:A.bT,CanvasPixelArray:A.bT,Uint8Array:A.aQ})
hunkHelpers.setOrUpdateLeafTags({SharedArrayBuffer:true,ArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.N.$nativeSuperclassTag="ArrayBufferView"
A.c9.$nativeSuperclassTag="ArrayBufferView"
A.ca.$nativeSuperclassTag="ArrayBufferView"
A.bQ.$nativeSuperclassTag="ArrayBufferView"
A.cb.$nativeSuperclassTag="ArrayBufferView"
A.cc.$nativeSuperclassTag="ArrayBufferView"
A.bR.$nativeSuperclassTag="ArrayBufferView"})()
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
var s=A.l7
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()
//# sourceMappingURL=pdfium_worker.js.map
