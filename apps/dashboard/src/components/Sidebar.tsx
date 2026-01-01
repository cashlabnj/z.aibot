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
