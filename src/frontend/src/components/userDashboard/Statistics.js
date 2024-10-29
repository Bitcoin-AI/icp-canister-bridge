// src/components/UserDashboard/Statistics.jsx
import React from 'react';
import {
    Card,
    CardContent,
    CardDescription,
    CardFooter,
    CardHeader,
    CardTitle,
  } from "../ui/Card"
  
const Statistics = ({ stats }) => {
  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
      <Card>
        <CardHeader>
            <CardTitle>Total Transactions</CardTitle>
            <CardDescription></CardDescription>
        </CardHeader>
        <CardContent>
            <p>{stats.totalTransactions}</p>
        </CardContent>
        <CardFooter>
            <p>Card Footer</p>
        </CardFooter>
      </Card>
      <Card>
        <CardHeader>
            <CardTitle>Total Volume</CardTitle>
            <CardDescription></CardDescription>
        </CardHeader>
        <CardContent>
            <p>{stats.transactionVolume}</p>
        </CardContent>
        <CardFooter>
            <p>Card Footer</p>
        </CardFooter>
      </Card>
    </div>
  );
};

export default Statistics;
