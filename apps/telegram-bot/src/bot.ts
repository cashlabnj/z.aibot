import { Bot, Keyboard } from 'grammy';
import axios from 'axios';
const API_URL = process.env.API_URL || 'http://api:3000/api';
const api = axios.create({ baseURL: API_URL });
export const bot = new Bot(process.env.TELEGRAM_BOT_TOKEN!);
const mainMenu = new Keyboard().text("Portfolio").row().text("Strategies").resized();
bot.command("start", async (ctx) => { ctx.reply("Welcome to PolyTrader. Please link your account.", { reply_markup: mainMenu }); });
bot.hears("Portfolio", async (ctx) => { const tgId = ctx.from!.id.toString(); const res = await api.get(`/portfolio/${tgId}`); ctx.reply(`Balance: $${res.data.totalBalanceUsdc}`); });
bot.hears("Strategies", async (ctx) => { ctx.reply("Strategy list coming soon."); });
