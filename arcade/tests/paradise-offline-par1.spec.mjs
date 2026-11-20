import {test,expect} from '@playwright/test';

test('PAR-1 completes an offline homestead day as a local-only result',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('paradise-offline-par1');
 await game.locator('button[part=start]').click();
 await game.locator('button[data-key=offline]').click();
 await expect(game.locator('[data-step=offline-ready]')).toBeVisible();
 await game.locator('[data-key=begin-day]').click();
 await expect(game.locator('[data-step=tasks]')).toBeVisible();
 for(const action of ['feed','repair','rest']){
  await game.locator('button[data-key='+action+']').click();
  if(action!=='rest') await expect(game.locator('[data-step=tasks]')).toBeVisible({timeout:4000});
 }
 await expect(game.locator('[data-step=report]')).toBeVisible({timeout:4000});
 await game.locator('button[data-key=complete-report]').click();
 await expect(game.locator('.overlay')).toContainText('DAY ONE COMPLETE');
 await expect(game.locator('[part=save-score]')).toHaveCount(0);
});

test('PAR-1 keeps the private room unlisted and prices its optional sponsor cutaway',async({page})=>{
 await page.goto('/demo/');
 const game=page.locator('paradise-offline-par1');
 await game.locator('button[part=start]').click();
 await game.locator('button[data-key=live]').click();
 await game.locator('button[data-key=camera-coop]').click();
 await game.locator('button[data-key=begin-day]').click();
 await game.locator('button[data-key=feed]').click();
 await expect(game.locator('[data-step=message]')).toBeVisible({timeout:4000});
 await game.locator('button[data-key=use-tip]').click();
 await game.locator('button[data-key=repair]').click();
 await expect(game.locator('[data-step=sponsor]')).toBeVisible({timeout:4000});
 await expect(game.locator('[data-step=sponsor]')).toContainText('boundaries −25');
 await game.locator('button[data-key=accept-sponsor]').click();
 await expect(game.locator('[data-step=report]')).toBeVisible({timeout:4000});
 await game.locator('button[data-key=complete-report]').click();
 await expect(game.locator('.overlay')).toContainText('boundaries −25');
 await expect(game.locator('[part=save-score]')).toHaveCount(0);
});
