#!/bin/bash

echo "🔧 Creating PolyTrader Project Structure..."

mkdir -p apps/api/src/{vault,trading,prisma,auth}
mkdir -p apps/dashboard/src/{app,components,lib}
mkdir -p apps/telegram-bot/src

cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: poly
      POSTGRES_PASSWORD: password
      POSTGRES_DB: polymarket
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
  redis:
    image: redis:alpine
    ports:
      - "6379:6379"
  api:
    build: ./apps/api
    ports:
      - "3000:3000"
    env_file:
      - .env
    depends_on:
      - db
      - redis
  dashboard:
    build: ./apps/dashboard
    ports:
      - "3001:3000"
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:3000
    depends_on:
      - api
  bot:
    build: ./apps/telegram-bot
    env_file:
      - .env
    depends_on:
      - redis
      - api
volumes:
  pgdata:
EOF

cat > package.json << 'EOF'
{
  "name": "poly-trader-app",
  "private": true,
  "scripts": {
    "dev": "turbo run dev",
    "build": "turbo run build",
    "db:push": "cd apps/api && npx prisma db push"
  },
  "devDependencies": {
    "turbo": "^1.11.2"
  },
  "workspaces": [
    "apps/*"
  ]
}
EOF

cat > .env.example << 'EOF'
DATABASE_URL="postgresql://poly:password@db:5432/polymarket"
REDIS_URL="redis://redis:6379"
POLY_HOST="https://clob.polymarket.com"
POLY_CHAIN_ID="137"
ENCRYPTION_MASTER_KEY="0123456789abcdef0123456789abcdef"
TELEGRAM_BOT_TOKEN="123456:ABC-DEF..."
EOF

cat > apps/api/package.json << 'EOF'
{
  "name": "api",
  "scripts": {
    "start": "node dist/main.js",
    "build": "nest build",
    "dev": "nest start --watch"
  },
  "dependencies": {
    "@nestjs/common": "^10.0.0",
    "@nestjs/core": "^10.0.0",
    "@nestjs/platform-express": "^10.0.0",
    "@nestjs/config": "^3.0.0",
    "@nestjs/microservices": "^10.0.0",
    "prisma": "^5.0.0",
    "@prisma/client": "^5.0.0",
    "@polymarket/clob-client": "0.1.11",
    "ethers": "^6.8.0",
    "ioredis": "^5.3.2",
    "class-validator": "^0.14.0",
    "class-transformer": "^0.5.1",
    "reflect-metadata": "^0.1.13",
    "rxjs": "^7.8.1"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.0.0",
    "@nestjs/schematics": "^10.0.0",
    "@types/express": "^4.17.17",
    "@types/node": "^20.3.1",
    "typescript": "^5.1.3"
  }
}
EOF

cat > apps/api/src/main.ts << 'EOF'
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { Transport, MicroserviceOptions } from '@nestjs/microservices';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.enableCors();

  app.connectMicroservice<MicroserviceOptions>({
    transport: Transport.REDIS,
    options: { url: process.env.REDIS_URL },
  });

  await app.startAllMicroservices();
  await app.listen(3000);
  console.log(`API running on port 3000`);
}
bootstrap();
EOF

cat > apps/api/src/app.module.ts << 'EOF'
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
EOF

cat > apps/api/src/app.controller.ts << 'EOF'
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
EOF

cat > apps/api/src/vault/vault.service.ts << 'EOF'
import { Injectable } from '@nestjs/common';
import * as crypto from 'crypto';

@Injectable()
export class VaultService {
  private readonly algorithm = 'aes-256-gcm';
  private readonly key = Buffer.from(process.env.ENCRYPTION_MASTER_KEY || '', 'hex');

  encrypt(privateKey: string): string {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv(this.algorithm, this.key, iv);
    let encrypted = cipher.update(privateKey, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    const authTag = cipher.getAuthTag();
    return `${iv.toString('hex')}:${authTag.toString('hex')}:${encrypted}`;
  }

  decrypt(encryptedString: string): string {
    const parts = encryptedString.split(':');
    const iv = Buffer.from(parts[0], 'hex');
    const authTag = Buffer.from(parts[1], 'hex');
    const encrypted = parts[2];
    const decipher = crypto.createDecipheriv(this.algorithm, this.key, iv);
    decipher.setAuthTag(authTag);
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  }
}
EOF

cat > apps/api/src/trading/polymarket.service.ts << 'EOF'
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
EOF

cat > apps/dashboard/package.json << 'EOF'
{
  "name": "dashboard",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "14.1.0",
    "react": "^18",
    "react-dom": "^18",
    "axios": "^1.6.0",
    "lucide-react": "^0.300.0",
    "clsx": "^2.1.0",
    "tailwind-merge": "^2.2.0"
  },
  "devDependencies": {
    "@types/node": "^20",
    "@types/react": "^18",
    "tailwindcss": "^3.3.0",
    "typescript": "^5"
  }
}
EOF

cat > apps/dashboard/src/app/layout.tsx << 'EOF'
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Sidebar } from "@/components/Sidebar";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });

export const metadata: Metadata = {
  title: "PolyTrader",
  description: "Automated Trading Dashboard",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className={`${inter.variable} bg-black text-white antialiased`}>
        <div className="flex min-h-screen">
          <Sidebar />
          <main className="flex-1 pl-64">{children}</main>
        </div>
      </body>
    </html>
  );
}
EOF

cat > apps/dashboard/src/app/page.tsx << 'EOF'
"use client";

export default function OverviewPage() {
  return (
    <div className="p-8">
      <h1 className="text-3xl font-bold mb-6">Overview</h1>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="p-6 bg-[#1C1C1E] rounded-2xl border border-[#333]">
          <h3 className="text-gray-500 text-sm">Total Balance</h3>
          <div className="text-3xl font-bold mt-2">$12,450.00</div>
          <div className="text-sm text-green-500 mt-1">+4.2%</div>
        </div>
        <div className="p-6 bg-[#1C1C1E] rounded-2xl border border-[#333]">
          <h3 className="text-gray-500 text-sm">Active Strategies</h3>
          <div className="text-3xl font-bold mt-2">3</div>
          <div className="text-sm text-gray-400 mt-1">Operational</div>
        </div>
      </div>
    </div>
  );
}
EOF

cat > apps/dashboard/src/components/Sidebar.tsx << 'EOF'
"use client";
import Link from 'next/link';
import { LayoutDashboard, TrendingUp, Activity, Settings } from 'lucide-react';

export function Sidebar() {
  return (
    <aside className="fixed left-0 top-0 h-screen w-64 border-r border-[#333] bg-black/90 backdrop-blur-xl z-40">
      <div className="flex h-14 items-center border-b border-[#333] px-6">
        <span className="font-bold text-white tracking-tight">PolyTrader</span>
      </div>
      <div className="flex flex-col p-4 space-y-2">
        <Link href="/" className="flex items-center gap-3 px-4 py-3 text-sm text-gray-400 hover:bg-[#1C1C1E] hover:text-white rounded-lg transition-colors"><LayoutDashboard size={20}/> Overview</Link>
        <Link href="/markets" className="flex items-center gap-3 px-4 py-3 text-sm text-gray-400 hover:bg-[#1C1C1E] hover:text-white rounded-lg transition-colors"><TrendingUp size={20}/> Markets</Link>
        <Link href="/strategies" className="flex items-center gap-3 px-4 py-3 text-sm text-gray-400 hover:bg-[#1C1C1E] hover:text-white rounded-lg transition-colors"><Activity size={20}/> Strategies</Link>
        <Link href="/settings" className="flex items-center gap-3 px-4 py-3 text-sm text-gray-400 hover:bg-[#1C1C1E] hover:text-white rounded-lg transition-colors"><Settings size={20}/> Settings</Link>
      </div>
    </aside>
  );
}
EOF

cat > apps/dashboard/src/app/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
:root { --foreground-rgb: 255, 255, 255; }
body { background: #000; color: rgb(var(--foreground-rgb)); }
EOF

cat > apps/dashboard/tailwind.config.ts << 'EOF'
import type { Config } from "tailwindcss";
const config: Config = {
  darkMode: "class",
  content: [ "./src/pages/**/*.{js,ts,jsx,tsx,mdx}", "./src/components/**/*.{js,ts,jsx,tsx,mdx}", "./src/app/**/*.{js,ts,jsx,tsx,mdx}", ],
  theme: { extend: { colors: { background: '#000000', surface: '#1C1C1E', border: '#333333', primary: '#0A84FF', success: '#30D158', danger: '#FF453A' } } },
  plugins: [],
};
export default config;
EOF

cat > apps/telegram-bot/package.json << 'EOF'
{
  "name": "telegram-bot",
  "scripts": {
    "start": "ts-node src/main.ts"
  },
  "dependencies": {
    "grammy": "^1.19.0",
    "ioredis": "^5.3.2",
    "axios": "^1.6.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "@types/node": "^20",
    "ts-node": "^10.9.2"
  }
}
EOF

cat > apps/telegram-bot/src/bot.ts << 'EOF'
import { Bot, Keyboard } from 'grammy';
import axios from 'axios';
const API_URL = process.env.API_URL || 'http://api:3000/api';
const api = axios.create({ baseURL: API_URL });
export const bot = new Bot(process.env.TELEGRAM_BOT_TOKEN!);
const mainMenu = new Keyboard().text("Portfolio").row().text("Strategies").resized();
bot.command("start", async (ctx) => { ctx.reply("Welcome to PolyTrader. Please link your account.", { reply_markup: mainMenu }); });
bot.hears("Portfolio", async (ctx) => { const tgId = ctx.from!.id.toString(); const res = await api.get(`/portfolio/${tgId}`); ctx.reply(`Balance: $${res.data.totalBalanceUsdc}`); });
bot.hears("Strategies", async (ctx) => { ctx.reply("Strategy list coming soon."); });
EOF

cat > apps/telegram-bot/src/alerts.ts << 'EOF'
import Redis from 'ioredis';
import { bot } from './bot';
const redis = new Redis(process.env.REDIS_URL);
redis.subscribe('trade_executed', (err) => { if (err) console.error(err); console.log("Listening for trades..."); });
redis.on('message', (channel, message) => { const data = JSON.parse(message); bot.api.sendMessage(data.telegramId, `Trade Alert: ${data.side} ${data.size} @ ${data.price}`); });
EOF

cat > apps/telegram-bot/src/main.ts << 'EOF'
import { bot } from './bot';
import './alerts';
bot.start();
EOF

cat > apps/api/Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN npm run build
CMD ["npm", "run", "start:prod"]
EOF

cat > apps/dashboard/Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN npm run build
CMD ["npm", "start"]
EOF

cat > apps/telegram-bot/Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm install
COPY . .
CMD ["npm", "start"]
EOF

echo "✅ Project structure created successfully!"
