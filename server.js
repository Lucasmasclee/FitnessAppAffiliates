const express = require('express');
const app = express();
const path = require('path');
const { v4: uuidv4 } = require('uuid');

app.use(express.static('public'));

// Route voor de landing page
app.get('/', (req, res) => {
  // Genereer een unieke tracking code
  const trackingCode = uuidv4();
  
  // Stuur de HTML-pagina met de tracking code
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Route om de tracking code op te halen
app.get('/generate-code', (req, res) => {
  const trackingCode = uuidv4();
  res.json({ trackingCode });
});

// Route om door te sturen naar de juiste app store
app.get('/redirect', (req, res) => {
  const { platform, trackingCode } = req.query;
  
  console.log(`Redirecting user with tracking code: ${trackingCode} to platform: ${platform}`);
  
  // Sla de tracking code op in de URL als een parameter
  if (platform === 'android') {
    // Gebruik je echte Android app ID
    res.redirect(`https://play.google.com/store/apps/details?id=com.Mascelli.FitnessApp&referrer=tracking_code%3D${trackingCode}`);
  } else if (platform === 'ios') {
    // Gebruik je echte iOS app ID
    res.redirect(`https://apps.apple.com/app/id1234567890?mt=8&ct=${trackingCode}`);
  } else {
    // Fallback voor onbekende platforms
    res.redirect('/');
  }
});

// Testroute om te controleren of tracking codes worden gegenereerd
app.get('/test-tracking', (req, res) => {
  res.send(`
    <h1>Tracking Test</h1>
    <p>Generated tracking code: ${uuidv4()}</p>
    <p><a href="/redirect?platform=android&trackingCode=${uuidv4()}">Test Android Redirect</a></p>
    <p><a href="/redirect?platform=ios&trackingCode=${uuidv4()}">Test iOS Redirect</a></p>
  `);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server draait op poort ${PORT}`);
});
