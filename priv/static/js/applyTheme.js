var pref=document.currentScript.dataset.pref;function reapplyTheme(){var e=pref||"system",a=window.matchMedia("(prefers-color-scheme: dark)").matches,t=document.querySelector("html"),r=document.getElementsByClassName("h-captcha");t.classList.remove("dark");for(let e=0;e<r.length;e++)r[e].dataset.theme="light";switch(e){case"dark":t.classList.add("dark");for(let e=0;e<r.length;e++)r[e].dataset.theme="dark";break;case"system":if(a){t.classList.add("dark");for(let e=0;e<r.length;e++)r[e].dataset.theme="dark"}}}reapplyTheme(),window.matchMedia("(prefers-color-scheme: dark)").addListener(reapplyTheme),window.onload=function(){reapplyTheme()};