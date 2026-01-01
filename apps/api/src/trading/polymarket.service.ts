import { Injectable, Logger } from '@nestjs/common';
import { ClobClient } from '@polymarket/clob-client';
import { ethers } from 'ethers';
import { InjectRedis } from '@nestjs-modules/ioredis';
import Redis from 'ioredis';
import { VaultService } from '../vault/vault.service';

@Injectable()
export class PolymarketService {
  private readonly logger = new Logger(PolymarketService.name);
  constructor(
    @InjectRedis() private readonly redis: Redis, 
    private vaultService: VaultService
  ) {}

  async getClient(encryptedKey: string): Promise<ClobClient> {
    const pk = this.vaultService.decrypt(encryptedKey);
    const wallet = new ethers.Wallet(pk);
    return new ClobClient(process.env.POLY_HOST, process.env.POLY_CHAIN_ID, wallet);
  }

  async executeOrder(encryptedKey: string, marketData: any, telegramId: string) {
    const client = await this.getClient(encryptedKey);
    const orderArgs = {
      tokenID: marketData.tokenId,
      price: Math.floor(marketData.price * 1_000_000),
      size: Math.floor(marketData.size * 1_000_000),
      side: marketData.side,
      nonce: Date.now()
    };

    try {
      const response: any = await client.createOrder(orderArgs);
      await this.redis.publish('trade_executed', JSON.stringify({
        telegramId,
        orderId: response.orderID,
        side: marketData.side,
        price: marketData.price,
        size: marketData.size,
        market: marketData.question
      }));
      return { success: true, orderId: response.orderID };
    } catch (error) {
      this.logger.error(error);
      throw error;
    }
  }
}
