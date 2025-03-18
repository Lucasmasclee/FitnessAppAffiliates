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
  
  // Sla de tracking code op in de URL als een parameter
  if (platform === 'android') {
    // Vervang JOUW_ANDROID_APP_ID door je echte app ID
    res.redirect(`https://play.google.com/apps/testing/com.Mascelli.RijlesPlanner&referrer=tracking_code%3D${trackingCode}`);
  } else if (platform === 'ios') {
    // Vervang JOUW_IOS_APP_ID door je echte app ID
    res.redirect(`https://apps.apple.com/app/idJOUW_IOS_APP_ID?mt=8&ct=${trackingCode}`);
  } else {
    // Fallback voor onbekende platforms
    res.redirect('/');
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server draait op poort ${PORT}`);
});
