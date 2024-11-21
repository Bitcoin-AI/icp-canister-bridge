// src/components/UserDashboard/UserProfile.jsx
import React from 'react';
import {Badge} from '../ui/Badge';

const UserProfile = ({ user }) => {
  return (
    <div className="flex items-center space-x-4">
      <div>
        <h2 className="text-lg font-semibold">{user.name}</h2>
        <Badge>Badge</Badge>
      </div>
    </div>
  );
};

export default UserProfile;
