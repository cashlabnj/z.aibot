import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { VaultService } from './vault/vault.service';
import { PolymarketService } from './trading/polymarket.service';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true })],
  controllers: [AppController],
  providers: [VaultService, PolymarketService],
})
export class AppModule {}
