import Redis from 'ioredis';
import { bot } from './bot';
const redis = new Redis(process.env.REDIS_URL);
redis.subscribe('trade_executed', (err) => { if (err) console.error(err); console.log("Listening for trades..."); });
redis.on('message', (channel, message) => { const data = JSON.parse(message); bot.api.sendMessage(data.telegramId, `Trade Alert: ${data.side} ${data.size} @ ${data.price}`); });
