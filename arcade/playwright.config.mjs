import {defineConfig,devices} from '@playwright/test';
export default defineConfig({
 testDir:'./tests',testMatch:'**/*.spec.mjs',timeout:30_000,expect:{timeout:8_000},
 fullyParallel:false,reporter:[['list'],['html',{open:'never',outputFolder:'playwright-report'}]],
 use:{baseURL:'http://127.0.0.1:8080',trace:'retain-on-failure',screenshot:'only-on-failure'},
 projects:[
  {name:'desktop-chromium',use:{...devices['Desktop Chrome'],viewport:{width:1280,height:900}}},
  {name:'mobile-chromium',use:{...devices['Desktop Chrome'],viewport:{width:390,height:844},hasTouch:true,isMobile:true,deviceScaleFactor:2}},
  {name:'mobile-webkit',testMatch:['**/standalone-mobile.spec.mjs','**/tag-before-training.spec.mjs'],use:{...devices['iPhone 13'],viewport:{width:390,height:844}}}
 ],
 webServer:{command:'npm run dev',url:'http://127.0.0.1:8080/demo/',reuseExistingServer:!process.env.CI,timeout:30_000},
});

