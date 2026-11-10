import numpy as np, wave
SR=44100; D=15.0; N=int(SR*D)
t_all=np.arange(N)/SR
def env(n,a=0.005,r=0.3):
    t=np.arange(n)/SR; e=np.minimum(t/a,1)*np.exp(-t/r); return e
def put(buf,sig,at,gain=1.0):
    i=int(at*SR); sig=sig[:max(0,N-i)]; buf[i:i+len(sig)]+=sig*gain
def sine(f,n,ph=0): return np.sin(2*np.pi*f*np.arange(n)/SR+ph)
def hit(n=int(SR*1.6)):
    # impact : boom grave + bruit filtré
    t=np.arange(n)/SR
    f=60*np.exp(-t*3)+35
    boom=np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-t*2.2)
    noise=np.random.randn(n)*np.exp(-t*9)*0.35
    return boom*1.0+noise
def tick(n=int(SR*0.12),f=1400):
    t=np.arange(n)/SR; return (np.sin(2*np.pi*f*t)+0.4*np.sin(2*np.pi*2*f*t))*np.exp(-t*45)
def pop(n=int(SR*0.25),f=620):
    t=np.arange(n)/SR; ff=f*(1+1.5*np.exp(-t*30)); return np.sin(2*np.pi*np.cumsum(ff)/SR)*np.exp(-t*14)
def pad(freqs,dur,vol=0.12):
    n=int(SR*dur); t=np.arange(n)/SR; s=sum(np.sin(2*np.pi*f*t+i)+0.5*np.sin(2*np.pi*f*2.01*t) for i,f in enumerate(freqs))/len(freqs)
    e=np.minimum(t/1.0,1)*np.minimum((dur-t)/1.0,1); return s*e*vol
def trombone(n=int(SR*1.4)):
    t=np.arange(n)/SR
    f=np.where(t<0.35,293,np.where(t<0.7,277,np.where(t<1.0,261,246*np.exp(-(t-1.0)*0.5))))
    f=f*(1+0.012*np.sin(2*np.pi*6*t)*(t>0.9))
    ph=2*np.pi*np.cumsum(f)/SR
    s=np.sign(np.sin(ph))*0.5+np.sin(ph)*0.5+0.3*np.sin(2*ph)
    return s*np.minimum(t/0.03,1)*np.exp(-np.maximum(t-1.1,0)*6)
def chime(f=880,n=int(SR*0.9)):
    t=np.arange(n)/SR; return (np.sin(2*np.pi*f*t)+0.5*np.sin(2*np.pi*f*2.76*t))*np.exp(-t*5)
def save(name,buf):
    buf=buf/np.max(np.abs(buf))*0.85
    st=np.stack([buf,buf],1); pcm=(st*32767).astype('<i2')
    w=wave.open(name,'wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes()); w.close()
np.random.seed(3)
# ── Pacte : suspense sombre ──
b=np.zeros(N)
put(b,pad([55,82.4,110],15,0.35),0,1)          # drone grave
put(b,pad([220,261.6,311],5.2,0.10),0.6)       # nappe sombre sous le hook
put(b,hit(),0,1.0)                              # impact sur le « 26 »
for k,f in enumerate([196,185,174.6,164.8]):   # descente mélancolique
    put(b,chime(f,int(SR*1.2))*0.35,3.0+k*0.5)
put(b,pop(),5.65,0.5)                           # « 14 octobre »
put(b,hit(int(SR*1.2)),9.05,0.8)                # « Le flow est cassé »
put(b,chime(659,int(SR*1.0))*0.4,11.0+0.73)     # relance
put(b,pop(),11.35,0.6)                          # bandeau « Oui ou non »
# fade fin
b*=np.minimum((D-t_all)/0.8,1)
save('pacte.wav',b)
# ── Prix : ironique ──
c=np.zeros(N)
put(c,hit(int(SR*1.0)),0,0.6)
put(c,pad([130.8,196,261.6],15,0.10),0,1)
for k in range(6):                              # chaque ❌ tombe sur un tic
    at=(75+14+26*k)/30
    put(c,tick(f=1100+k*40),at,0.9); put(c,pop(f=300),at,0.5)
put(c,trombone(),265/30+0.05,0.7)               # « Bilan : 0/6 »
put(c,pop(),(320+22)/30,0.6)
put(c,chime(784,int(SR*0.9))*0.4,(320+22)/30+0.05)
c*=np.minimum((D-t_all)/0.8,1)
save('prix.wav',c)
# ── Stats 120 h : positif, énergique ──
e=np.zeros(N)
put(e,pad([130.8,164.8,196],15,0.14),0,1)
put(e,hit(int(SR*1.2)),0,0.9)
put(e,chime(1046,int(SR*1.0))*0.45,0.12)
put(e,pop(),3.0+0.05,0.6)                        # « Soit 5 jours entiers »
put(e,chime(784,int(SR*0.8))*0.4,3.05)
for k,f in enumerate([659,784,988]):             # 31 / 214 / 34 : tintements montants
    at=(175+k*40)/30
    put(e,pop(f=500+k*120),at,0.7); put(e,chime(f,int(SR*0.9))*0.45,at+0.02)
put(e,pop(),(330+22)/30,0.6)
put(e,chime(880,int(SR*0.9))*0.4,(330+22)/30+0.05)
e*=np.minimum((D-t_all)/0.8,1)
save('stats.wav',e)
