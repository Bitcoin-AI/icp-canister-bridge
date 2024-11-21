// src/components/UserDashboard/UserDashboard.jsx
import React, { useState } from 'react';
import UserProfile from './UserProfile';
import Statistics from './Statistics';
import Notifications from './Notifications';

const UserDashboard = () => {
  const [transactions, setTransactions] = useState([]);
  const [filter, setFilter] = useState('All');
  const [searchQuery, setSearchQuery] = useState('');

  const user = {
    name: 'John Doe',
    avatar: '/avatar.jpg', // Ensure this path is correct or replace with a valid URL
    status: 'online',
    accountType: 'Premium User',
  };

  const stats = {
    totalTransactions: 0,
    transactionVolume: '$10,000',
    monthlyUsage: 80,
    monthlyLimit: 100,
  };

  const handleFilterChange = (value) => {
    setFilter(value);
    applyFilters(value, searchQuery);
  };

  const handleSearch = (query) => {
    setSearchQuery(query);
    applyFilters(filter, query);
  };

  const applyFilters = (status, query) => {
    let filtered = [];

    if (status !== 'All') {
      filtered = filtered.filter((txn) => txn.status === status);
    }

    if (query) {
      filtered = filtered.filter((txn) =>
        txn.id.toLowerCase().includes(query.toLowerCase())
      );
    }

    setTransactions(filtered);
  };

  return (
    <div className="p-6 bg-gray-50 min-h-screen">
      <div className="flex justify-between items-center mb-6">
        <UserProfile user={user} />
        <Notifications />
      </div>
      <Statistics stats={stats} />
    </div>
  );
};

export default UserDashboard;
