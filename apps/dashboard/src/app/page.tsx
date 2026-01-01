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
