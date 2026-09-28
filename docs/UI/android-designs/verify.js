/* Playwright browser_run_code에 전달하는 시안 회귀 점검 함수. */
async (page) => {
 const results=[];
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const check=(ok,label)=>{if(!ok)throw Error(label);results.push(label)};
 const app=page.locator('#app');
 for(const design of 'ABCDE'){
  await page.evaluate(d=>{setDesign(d);state.size='small';render()},design);
  await app.getByRole('button',{name:'검색',exact:true}).click();
  await app.getByRole('searchbox',{name:'앨범 검색'}).fill('없는 제목');
  check(await app.getByText('검색 결과가 없습니다').isVisible(),design+' 검색 빈 결과');
  await app.getByRole('button',{name:'검색 지우기',exact:true}).click();
  await app.getByRole('button',{name:'검색',exact:true}).click();
  for(let i=0;i<4;i++)await app.getByRole('button',{name:'보기 방식',exact:true}).click();
  check(await page.evaluate(()=>state.view==='grid'),design+' 네 가지 보기 전환');
  await app.getByRole('button',{name:'정렬',exact:true}).first().click();
  await app.getByRole('button',{name:'앨범명',exact:true}).click();
  check(await page.evaluate(()=>state.sort==='title'),design+' 정렬');
  await app.getByRole('button',{name:'더 보기',exact:true}).click();
  await app.getByRole('button',{name:'순서 변경',exact:true}).click();
  const before=await page.evaluate(()=>albums.map(a=>a.id).join());
  await app.locator('[data-move="down"]').first().click();
  check(before!==await page.evaluate(()=>albums.map(a=>a.id).join()),design+' 순서 이동');
  await page.evaluate(()=>{state.reorder=false;state.sort='custom';render()});
  await app.getByRole('button',{name:'앨범 추가',exact:true}).click();
  await app.getByRole('button',{name:'뒤로',exact:true}).click();
  check(await app.getByRole('dialog').isVisible(),design+' 미완료 입력 확인');
  await app.getByRole('button',{name:'계속 입력',exact:true}).click();
  await app.locator('[data-form="title"]').fill('검증 앨범');
  await app.locator('[data-form="artist"]').fill('샘플 아티스트');
  await page.waitForTimeout(720);
  check(await app.getByText('자동 저장됨',{exact:true}).isVisible(),design+' 필수 입력 자동 저장');
  await app.getByRole('button',{name:'디스크 추가',exact:true}).click();
  await app.locator('[data-add-disc-track="1"]').click();
  await app.locator('[data-disc-track="1:0:title"]').fill('트랙 원제');
  await app.locator('[data-disc-track="1:0:titleKr"]').fill('트랙 번역');
  await page.waitForTimeout(720);
  check(await page.evaluate(()=>albums.find(a=>a.id===state.selected).discs[1].tracks[0].titleKr==='트랙 번역'),design+' 디스크·한국어 트랙 저장');
  await app.getByRole('button',{name:'정보 검색',exact:true}).click();
  await app.getByRole('button',{name:'MusicBrainz에서 검색',exact:true}).click();
  await app.locator('#api-query').fill('샘플');
  await app.getByRole('button',{name:'검색',exact:true}).click();
  await app.locator('[data-action="choose-api-result"]').click();
  check(await app.locator('[data-form="title"]').inputValue()==='밤의 기록',design+' 검색 결과 적용');
  await app.getByRole('button',{name:'바코드 스캔',exact:true}).click();
  await app.getByRole('button',{name:'플래시 전환',exact:true}).click();
  await app.getByRole('button',{name:'카메라 전환',exact:true}).click();
  await app.getByRole('button',{name:'샘플 바코드 인식',exact:true}).click();
  check(await page.evaluate(()=>state.route==='add'),design+' 바코드 인식 후 복귀');
  await page.evaluate(()=>{clearTimeout(saveTimer);go('artistDetail')});
  await app.getByRole('button',{name:'아티스트 정보 편집',exact:true}).click();
  await app.locator('#artist-aliases').fill('샘플 별명');
  await app.locator('#artist-groups').fill('샘플 그룹');
  await app.getByRole('button',{name:'저장',exact:true}).click();
  check(await app.getByText(/배리에이션 · 샘플 별명/).isVisible(),design+' 아티스트 별명·소속');
  await page.evaluate(()=>go('settings'));
  await app.locator('[data-setting="discogs"]').fill('demo-only');
  await app.getByRole('button',{name:'보관함',exact:true}).click();
  check(await app.getByText('저장하지 않은 변경',{exact:true}).isVisible(),design+' 설정 미저장 경고');
  await app.getByRole('button',{name:'취소하고 나가기',exact:true}).click();
  await page.evaluate(()=>go('settings'));
  check(await app.locator('[data-setting="discogs"]').inputValue()==='',design+' 설정 취소');
  await app.locator('[data-setting="discogs"]').fill('demo-only');
  await app.getByRole('button',{name:'저장',exact:true}).first().click();
  await app.getByRole('button',{name:'백업 복원',exact:true}).click();
  await app.getByRole('button',{name:'취소',exact:true}).click();
  await app.getByRole('button',{name:'업데이트 확인',exact:true}).click();
  await app.getByRole('button',{name:'지금 업데이트',exact:true}).click();
  await app.getByRole('button',{name:'완료 상태 보기',exact:true}).click();
  check(await app.getByText('설치 완료 · 앱 재시작 안내',{exact:true}).isVisible(),design+' 업데이트 상태');
  await page.keyboard.press('Escape');
  check(await app.getByRole('button',{name:'업데이트 확인',exact:true}).evaluate(el=>el===document.activeElement),design+' 모달 포커스 복귀');
  await page.evaluate(()=>{go('home');state.section='collection';state.display='success';render()});
  await app.locator('[data-album]').first().click();
  await app.getByRole('button',{name:'앨범 삭제',exact:true}).click();
  const dialog=app.getByRole('dialog');
  await dialog.getByRole('button',{name:'취소',exact:true}).focus();
  await page.keyboard.press('Shift+Tab');
  check(await dialog.getByRole('button',{name:'삭제',exact:true}).evaluate(el=>el===document.activeElement),design+' 모달 키보드 순환');
  await dialog.getByRole('button',{name:'삭제',exact:true}).click();
  await app.getByRole('button',{name:'실행 취소',exact:true}).click();
  for(const s of ['loading','empty','error','disabled']){
   await page.locator('#state-choice').selectOption(s);
   check(await app.locator('.state-card').isVisible(),design+' '+s+' 상태');
   if(s==='disabled')check(await app.locator('[data-action="add"]').isDisabled(),design+' 비활성 차단');
  }
  await page.locator('#state-choice').selectOption('success');
  await page.locator('#motion-choice').selectOption('none');
  await page.locator('#motion-demo').click();
  check(await app.evaluate(el=>el.getAnimations({subtree:true}).length===0),design+' 모션 없음');
 }
 const geometry=await page.evaluate(()=>{
  const problems=[],contrasts=[];const app=document.querySelector('#app');
  const luminance=raw=>{let h=raw.slice(1);if(h.length===3)h=[...h].map(c=>c+c).join('');let c=[0,2,4].map(i=>parseInt(h.slice(i,i+2),16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);return c[0]*.2126+c[1]*.7152+c[2]*.0722};
  for(const d of 'ABCDE'){
   setDesign(d);
   for(const dark of [false,true]){
    state.dark=dark;state.lightC=!dark;render();const css=getComputedStyle(app),v=k=>css.getPropertyValue('--'+k).trim();
    for(const [a,b] of [['ink','bg'],['muted','bg'],['ink','surface'],['muted','surface'],['accent','accent-ink'],['error','surface'],['control','surface']]){
     let x=luminance(v(a)),y=luminance(v(b)),r=(Math.max(x,y)+.05)/(Math.min(x,y)+.05);contrasts.push({d,dark,pair:a+'/'+b,ratio:+r.toFixed(2)});if(!Number.isFinite(r)||r<(a==='control'?3:4.5))problems.push({d,dark,a,b,r});
    }
   }
   for(const size of ['small','phone','tablet','wide'])for(const large of [false,true]){
    state.size=size;state.large=large;
    for(const route of ['home','detail','songs','artists','artistDetail','add','settings','scanner']){
     if(route==='add')beginAdd();else{state.route=route;render()}
     const screen=app.querySelector('.screen');if(screen.scrollWidth>screen.clientWidth+1)problems.push({d,size,large,route,overflow:screen.scrollWidth-screen.clientWidth});
     for(const el of app.querySelectorAll('button:not(:disabled),input,select')){let r=el.getBoundingClientRect();if(r.height&&(r.width<47.5||r.height<47.5))problems.push({d,size,large,route,target:el.getAttribute('aria-label')||el.textContent.slice(0,20),width:r.width,height:r.height})}
    }
   }
  }
  state.large=false;state.size='phone';setDesign('A');return {problems,contrasts};
 });
 check(!geometry.problems.length,JSON.stringify(geometry.problems));
 check(!errors.length,JSON.stringify(errors));
 return {checks:results.length,results,geometry};
}
