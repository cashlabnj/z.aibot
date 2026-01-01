import { Controller, Get, Post, Body, Param } from '@nestjs/common';
import { VaultService } from './vault/vault.service';
const mockPrisma = {
  user: {
    findUnique: async ({ where }: any) => {
      return null;
    }
  }
};

@Controller()
export class AppController {
  constructor(private vault: VaultService) {}

  @Get('auth/check-user/:telegramId')
  async checkUser(@Param('telegramId') telegramId: string) {
    return null;
  }

  @Post('auth/generate-token')
  async generateToken(@Body('telegramId') telegramId: string) {
    return { token: `link-${telegramId}-${Date.now()}` };
  }

  @Get('portfolio/:telegramId')
  async getPortfolio(@Param('telegramId') telegramId: string) {
    return { totalBalanceUsdc: 0, pnl24h: 0, positions: [] };
  }
}
