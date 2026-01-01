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
