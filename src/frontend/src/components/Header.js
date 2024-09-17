import React from "react";
import {
  AppBar,
  Toolbar,
  Typography,
  Button,
  Box,
  Container,
  Paper,
  Grid,
  Avatar,
  Tooltip,
  IconButton,
} from '@mui/material';
import { useTheme } from '@mui/material/styles';
//import { AccountBalanceWallet, Refresh } from '@mui/icons-material';

const Header = ({
  nodeInfo,
  netId,
  coinbase,
  fetchNodeInfo,
  rskBalance
}) => {

  const theme = useTheme();

  return (
    <>
      {/* AppBar Header */}
      <AppBar position="static">
        <Toolbar>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            EVM Lightning Bridge
          </Typography>
          {coinbase && (
            <Tooltip title="Connected Wallet">
              <Button color="inherit" >
                {`${coinbase.substring(0, 6)}...${coinbase.substring(coinbase.length - 4)}`}
              </Button>
            </Tooltip>
          )}
        </Toolbar>
      </AppBar>

      {/* Main Content */}
      <Container sx={{ mt: 4 }}>
        <Paper elevation={3} sx={{ p: 4 }}>
          <Typography variant="h4" gutterBottom>
            Welcome to EVM Lightning Bridge!
          </Typography>
          <Typography variant="body1" gutterBottom>
            Follow the steps below to bridge your assets.
          </Typography>

          {/* Node Info Section */}
          {typeof window.webln !== 'undefined' && (
            <Box sx={{ mt: 4 }}>
              <Typography variant="h5" gutterBottom>
                Lightning Node Information
              </Typography>
              <Button
                variant="contained"
                color="primary"
                onClick={fetchNodeInfo}
              >
                Fetch Node Info
              </Button>
              {nodeInfo && (
                <Paper elevation={2} sx={{ mt: 2, p: 2 }}>
                  <Grid container spacing={2} alignItems="center">
                    <Grid item>
                      <Avatar>{nodeInfo.node.alias.charAt(0)}</Avatar>
                    </Grid>
                    <Grid item xs>
                      <Typography variant="h6">{nodeInfo.node.alias}</Typography>
                      <Typography variant="body2" sx={{ wordBreak: 'break-all' }}>
                        Pubkey: {nodeInfo.node.pubkey}
                      </Typography>
                      <Typography variant="body2">
                        Balance: {nodeInfo.balance} sats
                      </Typography>
                    </Grid>
                  </Grid>
                </Paper>
              )}
            </Box>
          )}

          {/* EVM Info Section */}
          {coinbase && (
            <Box sx={{ mt: 4 }}>
              <Typography variant="h5" gutterBottom>
                EVM Connection
              </Typography>
              <Paper elevation={2} sx={{ mt: 2, p: 2 }}>
                <Grid container spacing={2}>
                  <Grid item xs={12} sm={6}>
                    <Typography variant="body1">
                      <strong>Address:</strong><br />
                      {coinbase}
                    </Typography>
                  </Grid>
                  <Grid item xs={12} sm={6}>
                    <Typography variant="body1">
                      <strong>Chain ID:</strong> {netId.toString()}
                    </Typography>
                  </Grid>
                  <Grid item xs={12}>
                    <Typography variant="body1">
                      <strong>Balance:</strong> {Math.round(rskBalance / 10 ** 10)} satoshis of {netId === 31 ? "RBTC" : "WBTC"}
                    </Typography>
                  </Grid>
                </Grid>
              </Paper>
            </Box>
          )}
        </Paper>
      </Container>
    </>
  );
};

export default Header;