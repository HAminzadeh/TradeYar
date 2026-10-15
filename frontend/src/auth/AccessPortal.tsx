import {useCallback,useEffect,useState,type FormEvent,type ReactNode} from 'react';
import {accessApi,AccessError,type AccessStatus,type AccessUser,type LoginResponse,type UserRole,type UserStatus,type RegistrationResponse} from './accessApi';

type View = 'LOGIN' | 'REGISTER' | 'APP' | 'USERS';
const roles:{value:UserRole;fa:string;summary:string}[] = [
  {value:'ADMIN',fa:'مدیر سیستم',summary:'مدیریت کاربران، پژوهش، گزارش‌ها و معاملات آزمایشی'},
  {value:'RESEARCH_MANAGER',fa:'مدیر پژوهش',summary:'مدیریت پژوهش، ارزیابی استراتژی و معاملات آزمایشی'},
  {value:'ANALYST',fa:'تحلیل‌گر',summary:'مشاهده پژوهش و اجرای تحلیل‌های مجاز'},
  {value:'VIEWER',fa:'فقط مشاهده',summary:'فقط دسترسی خواندن به نتایج و گزارش‌های پژوهشی'},
];
const states:{value:UserStatus;fa:string}[] = [
  {value:'PENDING',fa:'در انتظار تأیید'},{value:'ACTIVE',fa:'فعال'},{value:'SUSPENDED',fa:'تعلیق شده'},
];
const roleName = (r:UserRole) => roles.find(x=>x.value===r)?.fa ?? r;
const statusName = (s:UserStatus) => states.find(x=>x.value===s)?.fa ?? s;
const emptyRegister = {username:'',displayName:'',email:'',password:'',confirmPassword:''};
const emptyCreate = {username:'',displayName:'',email:'',password:'',role:'VIEWER' as UserRole,status:'ACTIVE' as UserStatus};

function Brand() {return <div className="ty-brand"><div className="ty-brand-icon" aria-hidden="true">↗</div><div><strong>تریدیار</strong><small>پلتفرم پژوهش معاملات · دسترسی کنترل‌شده</small></div></div>}
function ErrorNotice({error}:{error:string}) {return error ? <div className="ty-alert" role="alert">{error}</div> : null;}
function Field({title,value,onChange,type='text',autoComplete,required=true}:{title:string;value:string;onChange:(v:string)=>void;type?:string;autoComplete?:string;required?:boolean}) {
  return <label className="ty-field">{title}<input value={value} type={type} autoComplete={autoComplete} required={required} onChange={e=>onChange(e.currentTarget.value)} /></label>;
}
function SelectField<T extends string>({title,value,onChange,options}:{title:string;value:T;onChange:(v:T)=>void;options:{value:T;fa:string}[]}) {
  return <label className="ty-field">{title}<select value={value} onChange={e=>onChange(e.currentTarget.value as T)}>{options.map(x=><option key={x.value} value={x.value}>{x.fa}</option>)}</select></label>;
}

export default function AccessPortal({children}:{children:ReactNode}) {
  const [available,setAvailable]=useState<AccessStatus|null>(null);
  const [legacy,setLegacy]=useState(false);
  const [loading,setLoading]=useState(true);
  const [user,setUser]=useState<AccessUser|null>(null);
  const [view,setView]=useState<View>('LOGIN');
  const [error,setError]=useState('');
  const [busy,setBusy]=useState(false);
  const [username,setUsername]=useState('');
  const [password,setPassword]=useState('');
  const [registration,setRegistration]=useState(emptyRegister);
  const [registered,setRegistered]=useState('');
  const refresh = useCallback(async () => {
    try {
      const state = await accessApi<AccessStatus>('/api/v1/auth/status');
      setAvailable(state);
      if (state.enabled && state.configured) {
        try {const me=await accessApi<AccessUser>('/api/v1/auth/me');setUser(me);setView('APP');}
        catch (e) {if (e instanceof AccessError && e.status===401) {setUser(null);setView('LOGIN');} else throw e;}
      }
      setError('');
    } catch(e) {
      if(e instanceof AccessError && e.status===404) {setLegacy(true);return;}
      setError(e instanceof Error ? e.message : 'ارتباط با سرویس مدیریت کاربران برقرار نشد.');
    } finally {setLoading(false);}
  },[]);
  useEffect(()=>{void refresh()},[refresh]);
  const run = async (action:()=>Promise<void>) => {setError('');setBusy(true);try {await action();}catch(e){setError(e instanceof Error?e.message:'عملیات انجام نشد.')}finally{setBusy(false)}};
  const login = (e:FormEvent) => {e.preventDefault();void run(async()=>{
    const response=await accessApi<LoginResponse>('/api/v1/auth/login',{method:'POST',body:JSON.stringify({username,password})});
    setPassword('');setUser(response.user);setView('APP');
  })};
  const register = (e:FormEvent) => {e.preventDefault();if(registration.password!==registration.confirmPassword){setError('تکرار رمز عبور یکسان نیست.');return;}
    void run(async()=>{const res=await accessApi<RegistrationResponse>('/api/v1/auth/register',{method:'POST',body:JSON.stringify({username:registration.username,displayName:registration.displayName,email:registration.email||null,password:registration.password})});setRegistration(emptyRegister);setRegistered(res.message);setView('LOGIN')})};
  const logout = () => void run(async()=>{try{await accessApi<void>('/api/v1/auth/logout',{method:'POST'});}finally{setUser(null);setView('LOGIN')}});
  if (loading) return <div className="ty-access ty-auth-panel" role="status">در حال بررسی وضعیت دسترسی…</div>;
  // Older installations remain in clearly labelled demo mode until the backend is installed.
  if (legacy || (available && !available.enabled)) return <><div className="ty-alert info" role="status" style={{margin:0,borderRadius:0}}>حالت توسعه / دمو: احراز هویت کاربران هنوز فعال نشده است. برای فعال‌سازی، راهنمای نصب و Migration را دنبال کنید.</div>{children}</>;
  if (!available?.configured || error && !user && !available) return <div className="ty-access ty-auth-panel"><div className="ty-auth-card"><Brand/><ErrorNotice error={error||'سرویس مدیریت کاربران پیکربندی نشده است.'}/><button className="ty-btn" onClick={()=>{setLoading(true);void refresh()}}>تلاش دوباره</button></div></div>;
  if (!user) return <div className="ty-access"><div className="ty-auth-layout">
    <section className="ty-auth-panel"><div className="ty-auth-card"><Brand/>
      {view==='REGISTER'?<><h2>درخواست عضویت</h2><p className="ty-subtitle">حساب شما پس از تأیید مدیر فعال می‌شود.</p><ErrorNotice error={error}/>
        <form className="ty-form" onSubmit={register}>
          <Field title="نام کاربری" value={registration.username} onChange={v=>setRegistration(s=>({...s,username:v}))} autoComplete="username" />
          <Field title="نام نمایشی" value={registration.displayName} onChange={v=>setRegistration(s=>({...s,displayName:v}))} autoComplete="name" />
          <Field title="ایمیل (اختیاری)" type="email" required={false} value={registration.email} onChange={v=>setRegistration(s=>({...s,email:v}))} autoComplete="email" />
          <Field title="رمز عبور (حداقل ۱۲ کاراکتر)" type="password" value={registration.password} onChange={v=>setRegistration(s=>({...s,password:v}))} autoComplete="new-password" />
          <Field title="تکرار رمز عبور" type="password" value={registration.confirmPassword} onChange={v=>setRegistration(s=>({...s,confirmPassword:v}))} autoComplete="new-password" />
          <button className="ty-btn primary" disabled={busy}>ثبت درخواست عضویت</button>
        </form><button className="ty-link" onClick={()=>{setError('');setView('LOGIN')}}>بازگشت به ورود</button></>:
        <><h2>ورود به حساب کاربری</h2><p className="ty-subtitle">برای استفاده از محیط پژوهشی وارد شوید.</p>{registered&&<div className="ty-alert success">{registered}</div>}<ErrorNotice error={error}/>
          <form className="ty-form" onSubmit={login}><Field title="نام کاربری" value={username} onChange={setUsername} autoComplete="username"/><Field title="رمز عبور" type="password" value={password} onChange={setPassword} autoComplete="current-password"/><button className="ty-btn primary" disabled={busy}>{busy?'در حال بررسی…':'ورود به تریدیار'}</button></form>
          <button className="ty-link" onClick={()=>{setError('');setView('REGISTER')}}>ایجاد حساب کاربری جدید</button></>}
      <p className="ty-subtitle" style={{marginTop:18,fontSize:13}}>معاملات واقعی غیرفعال هستند؛ نقش کاربران مجوز ارسال سفارش واقعی نمی‌دهد.</p>
    </div></section>
    <aside className="ty-auth-side"><div className="ty-brand"><div className="ty-brand-icon">▥</div><div><strong>TradeYar</strong><small style={{color:'#D6E8F6'}}>FOREX RESEARCH WORKSTATION</small></div></div><h1>تحلیل داده، تصمیم‌گیری آگاهانه</h1><p>پژوهش استراتژی، بررسی نمودارها و مدیریت داده‌های تاریخی در محیطی یکپارچه و کنترل‌شده.</p><div className="ty-market-metrics"><span>◈ تحلیل بازار</span><span>↗ بک‌تست پژوهشی</span><span>◉ معاملات آزمایشی</span><span>⊘ اجرای واقعی قفل است</span></div></aside>
  </div></div>;
  return <div className="ty-access">
    <header className="ty-app-toolbar"><Brand/><div className="ty-toolbar-actions"><span className="ty-role-pill">{user.displayName} · {roleName(user.role)}</span><button className="ty-btn" onClick={()=>{setError('');setView('APP')}}>میزکار</button>{user.permissions.includes('USER_MANAGE')&&<button className="ty-btn" onClick={()=>{setError('');setView('USERS')}}>مدیریت کاربران</button>}<button className="ty-btn" disabled={busy} onClick={logout}>خروج امن</button></div></header>
    {view==='USERS' && user.permissions.includes('USER_MANAGE')?<UsersPage onError={setError}/>:children}
  </div>;
}

function UsersPage({onError}:{onError:(v:string)=>void}) {
  const [users,setUsers]=useState<AccessUser[]>([]);
  const [loading,setLoading]=useState(false);
  const [error,setError]=useState('');
  const [filter,setFilter]=useState('');
  const [editing,setEditing]=useState<AccessUser|null>(null);
  const [draft,setDraft]=useState({displayName:'',email:'',role:'VIEWER' as UserRole,status:'PENDING' as UserStatus});
  const [creating,setCreating]=useState(false);
  const [create,setCreate]=useState(emptyCreate);
  const [resetId,setResetId]=useState('');
  const [newPassword,setNewPassword]=useState('');
  const refresh = useCallback(async()=>{
    setLoading(true);try{setUsers(await accessApi<AccessUser[]>('/api/v1/admin/users'));setError('')}
    catch(e){setError(e instanceof Error?e.message:'دریافت کاربران ناموفق بود.')}finally{setLoading(false)}
  },[]);
  useEffect(()=>{void refresh()},[refresh]);
  const save = async(e:FormEvent) => {e.preventDefault();if(!editing)return;try{
    await accessApi<AccessUser>(`/api/v1/admin/users/${editing.id}`,{method:'PUT',body:JSON.stringify({...draft,email:draft.email||null})});setEditing(null);await refresh();
  }catch(err){setError(err instanceof Error?err.message:'ویرایش انجام نشد.')}};
  const createAccount = async(e:FormEvent)=>{e.preventDefault();try{
    await accessApi<AccessUser>('/api/v1/admin/users',{method:'POST',body:JSON.stringify({...create,email:create.email||null})});setCreate(emptyCreate);setCreating(false);await refresh();
  }catch(err){setError(err instanceof Error?err.message:'ایجاد کاربر انجام نشد.')}};
  const reset = async(e:FormEvent)=>{e.preventDefault();try{
    await accessApi<void>(`/api/v1/admin/users/${resetId}/reset-password`,{method:'POST',body:JSON.stringify({newPassword})});setResetId('');setNewPassword('');await refresh();
  }catch(err){setError(err instanceof Error?err.message:'بازنشانی رمز ناموفق بود.')}};
  const unlock = async(id:string)=>{try{await accessApi<void>(`/api/v1/admin/users/${id}/unlock`,{method:'POST'});await refresh()}catch(e){onError(e instanceof Error?e.message:'باز کردن قفل ناموفق بود.');setError(e instanceof Error?e.message:'خطا')}};
  const matching = users.filter(u=>[u.username,u.displayName,u.email||''].join(' ').toLowerCase().includes(filter.toLowerCase()));
  return <main className="ty-users"><div className="ty-users-head"><div><h2>کاربران و سطح دسترسی</h2><p className="ty-subtitle">تأیید ثبت‌نام، نقش‌های پژوهشی، وضعیت حساب و بازنشانی رمز عبور</p></div><button className="ty-btn primary" onClick={()=>setCreating(true)}>+ ایجاد کاربر</button></div>
    <ErrorNotice error={error}/><label className="ty-field" style={{maxWidth:420,marginBottom:20}}>جست‌وجوی کاربر<input type="search" value={filter} onChange={e=>setFilter(e.currentTarget.value)} placeholder="نام، نام کاربری یا ایمیل" /></label>
    {loading?<p className="ty-empty">در حال دریافت کاربران…</p>:matching.length===0?<p className="ty-empty">کاربری پیدا نشد.</p>:<div className="ty-cards">{matching.map(u=><article className="ty-user-card" key={u.id}><h3>{u.displayName}</h3><p dir="ltr" style={{textAlign:'right'}}>@{u.username}</p><p>{u.email||'ایمیل ثبت نشده'}</p><p>نقش: {roleName(u.role)}</p><span className={'ty-status '+u.status}>{statusName(u.status)}</span><p>آخرین ورود: {u.lastLoginAt?new Date(u.lastLoginAt).toLocaleString('fa-IR'):'هنوز وارد نشده'}</p><div className="ty-user-actions"><button className="ty-btn" onClick={()=>{setDraft({displayName:u.displayName,email:u.email||'',role:u.role,status:u.status});setEditing(u)}}>نقش و وضعیت</button><button className="ty-btn" onClick={()=>{setResetId(u.id);setNewPassword('')}}>بازنشانی رمز</button>{u.lockedUntil&&new Date(u.lockedUntil)>new Date()&&<button className="ty-btn" onClick={()=>void unlock(u.id)}>بازکردن قفل</button>}</div></article>)}</div>}
    {(editing||creating||resetId)&&<div className="ty-dialog-backdrop" role="presentation" onClick={()=>{setEditing(null);setCreating(false);setResetId('')}}><div className="ty-dialog" role="dialog" aria-modal="true" aria-label="مدیریت کاربر" onClick={e=>e.stopPropagation()}>
    {editing?<form className="ty-form" onSubmit={e=>void save(e)}><h3>ویرایش {editing.displayName}</h3><Field title="نام نمایشی" value={draft.displayName} onChange={v=>setDraft(x=>({...x,displayName:v}))}/><Field title="ایمیل" type="email" required={false} value={draft.email} onChange={v=>setDraft(x=>({...x,email:v}))}/><SelectField title="نقش" value={draft.role} onChange={v=>setDraft(x=>({...x,role:v}))} options={roles}/><p className="ty-subtitle">{roles.find(x=>x.value===draft.role)?.summary}</p><SelectField title="وضعیت" value={draft.status} onChange={v=>setDraft(x=>({...x,status:v}))} options={states}/><div className="ty-user-actions"><button className="ty-btn primary">ذخیره تغییرات</button><button type="button" className="ty-btn" onClick={()=>setEditing(null)}>انصراف</button></div></form>:
    creating?<form className="ty-form" onSubmit={e=>void createAccount(e)}><h3>ایجاد حساب کاربری</h3><Field title="نام کاربری" value={create.username} onChange={v=>setCreate(x=>({...x,username:v}))}/><Field title="نام نمایشی" value={create.displayName} onChange={v=>setCreate(x=>({...x,displayName:v}))}/><Field title="ایمیل (اختیاری)" type="email" required={false} value={create.email} onChange={v=>setCreate(x=>({...x,email:v}))}/><Field title="رمز اولیه" type="password" value={create.password} onChange={v=>setCreate(x=>({...x,password:v}))}/><SelectField title="نقش" value={create.role} onChange={v=>setCreate(x=>({...x,role:v}))} options={roles}/><SelectField title="وضعیت" value={create.status} onChange={v=>setCreate(x=>({...x,status:v}))} options={states}/><div className="ty-user-actions"><button className="ty-btn primary">ایجاد کاربر</button><button type="button" className="ty-btn" onClick={()=>setCreating(false)}>انصراف</button></div></form>:
    <form className="ty-form" onSubmit={e=>void reset(e)}><h3>بازنشانی رمز عبور</h3><Field title="رمز جدید (حداقل ۱۲ کاراکتر)" type="password" autoComplete="new-password" value={newPassword} onChange={setNewPassword}/><div className="ty-user-actions"><button className="ty-btn primary">تأیید تغییر رمز</button><button type="button" className="ty-btn" onClick={()=>setResetId('')}>انصراف</button></div></form>}
    </div></div>}
  </main>;
}
