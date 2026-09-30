/**
 * End-to-End API Integration & Acceptance Test
 * Tests the entire lifecycle:
 * 1. Health check
 * 2. Login with seeded demo credentials
 * 3. Token refresh rotation
 * 4. List Spaces
 * 5. Create a new Space ("AI & Systems Research")
 * 6. Create a Note inside the Space
 * 7. Create a Web Link inside the Space
 * 8. Search cross-space
 * 9. Star/Favorite a file
 * 10. List Favorites
 * 11. Trash a file & verify in Trash
 * 12. Restore the file from Trash
 * 13. Generate a secure Share Link
 * 14. Resolve the Share Link publicly (unauthenticated)
 * 15. Fetch Storage Statistics
 */

async function runE2ETests() {
  const BASE_URL = 'http://localhost:3000/api/v1';
  console.log('🚀 Starting Spaces End-to-End API Test Suite on', BASE_URL);

  let authToken = '';
  let refreshToken = '';
  let createdSpaceId = '';
  let createdNoteId = '';
  let createdLinkId = '';
  let shareToken = '';

  function assert(condition, message) {
    if (!condition) {
      console.error(`❌ FAILED: ${message}`);
      process.exit(1);
    }
    console.log(`✅ PASSED: ${message}`);
  }

  // 1. Health check
  const healthRes = await fetch('http://localhost:3000/health');
  assert(healthRes.status === 200, 'Health endpoint responds with 200');
  const healthData = await healthRes.json();
  assert(healthData.status === 'healthy', 'Health status is "healthy"');

  // 2. Login
  const loginRes = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'demo@spaces.app',
      password: 'Password123!',
    }),
  });
  assert(loginRes.status === 200, 'Demo user login succeeds');
  const loginData = await loginRes.json();
  authToken = loginData.data.tokens.accessToken;
  refreshToken = loginData.data.tokens.refreshToken;
  assert(!!authToken && !!refreshToken, 'Received access and refresh tokens');
  console.log(`   Logged in as: ${loginData.data.user.email} (${loginData.data.user.firstName})`);

  // Helper headers
  const authHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${authToken}`,
  };

  // 3. Token refresh
  const refreshRes = await fetch(`${BASE_URL}/auth/refresh`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken }),
  });
  if (refreshRes.status !== 200) {
    console.error(`Refresh error (${refreshRes.status}):`, await refreshRes.text());
  }
  assert(refreshRes.status === 200, 'Token refresh rotation succeeds');
  const refreshData = await refreshRes.json();
  authToken = refreshData.data.tokens.accessToken;
  authHeaders.Authorization = `Bearer ${authToken}`;
  assert(!!authToken, 'Acquired rotated access token');

  // 4. List Spaces
  const listSpacesRes = await fetch(`${BASE_URL}/spaces`, {
    headers: authHeaders,
  });
  assert(listSpacesRes.status === 200, 'List Spaces succeeds');
  const spacesData = await listSpacesRes.json();
  // Spaces come in paginated form: { data: [...], pagination: {...} }
  const spacesArray = spacesData.data || spacesData;
  assert(Array.isArray(spacesArray) && spacesArray.length >= 4, `Found ${spacesArray.length} seeded spaces`);

  // 5. Create a new Space
  const createSpaceRes = await fetch(`${BASE_URL}/spaces`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      name: 'AI & Systems Research',
      description: 'Paper reading, architecture notes, and ML experiments',
      icon: '🧠',
      color: '#6366F1',
      category: 'Projects',
      isPrivate: true,
    }),
  });
  if (createSpaceRes.status !== 201) {
    console.error('Create space error:', await createSpaceRes.text());
  }
  assert(createSpaceRes.status === 201, 'Create Space succeeds');
  const newSpace = (await createSpaceRes.json()).data;
  createdSpaceId = newSpace.id;
  assert(newSpace.name === 'AI & Systems Research', 'Space name verified');

  // 6. Create a Note inside the Space (POST /files/notes-links)
  const createNoteRes = await fetch(`${BASE_URL}/files/notes-links`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      spaceId: createdSpaceId,
      name: 'System Architecture Notes',
      type: 'NOTE',
      content: '# Spaces Platform Architecture\n\n- Cross-platform Flutter UI\n- Express 5 + Prisma backend\n- Contextual Spaces data model\n- Instant universal search',
    }),
  });
  if (createNoteRes.status !== 201) {
    console.error('Create note error:', await createNoteRes.text());
  }
  assert(createNoteRes.status === 201, 'Create Markdown Note succeeds');
  const noteData = (await createNoteRes.json()).data;
  createdNoteId = noteData.id;
  assert(noteData.category === 'NOTE', 'Note category verified');

  // 7. Create a Web Link inside the Space
  const createLinkRes = await fetch(`${BASE_URL}/files/notes-links`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      spaceId: createdSpaceId,
      name: 'Spaces Product Vision Doc',
      type: 'LINK',
      content: 'https://spaces.app/vision',
    }),
  });
  if (createLinkRes.status !== 201) {
    console.error('Create link error:', await createLinkRes.text());
  }
  assert(createLinkRes.status === 201, 'Create Web Link succeeds');
  const linkData = (await createLinkRes.json()).data;
  createdLinkId = linkData.id;
  assert(linkData.category === 'LINK', 'Link category verified');

  // 8. Universal Search (response: { spaces: [...], files: { data: [...], pagination: {...} } })
  const searchRes = await fetch(`${BASE_URL}/search?q=Architecture`, {
    headers: authHeaders,
  });
  assert(searchRes.status === 200, 'Universal search query succeeds');
  const searchResults = (await searchRes.json()).data;
  // Files are in paginated form under searchResults.files.data
  const searchedFiles = searchResults.files?.data || searchResults.files || [];
  assert(
    searchedFiles.some((f) => f.id === createdNoteId),
    'Search found newly created note by query term'
  );

  // 9. Star/Favorite a file (POST /files/:id/favorite)
  // Response: { isFavorite: true/false }
  const favRes = await fetch(`${BASE_URL}/files/${createdNoteId}/favorite`, {
    method: 'POST',
    headers: authHeaders,
  });
  assert(favRes.status === 200, 'Toggle Favorite succeeds');
  const favData = await favRes.json();
  assert(favData.data.isFavorite === true, 'File is now marked as favorite');

  // 10. List Favorites (GET /favorites → flat array)
  const listFavRes = await fetch(`${BASE_URL}/favorites`, {
    headers: authHeaders,
  });
  assert(listFavRes.status === 200, 'List favorites succeeds');
  const favList = (await listFavRes.json()).data;
  assert(Array.isArray(favList), 'Favorites is an array');
  assert(favList.some((f) => f.id === createdNoteId), 'Favorite appears in favorites list');

  // 11. Trash a file (POST /files/:id/trash) & verify in Trash (GET /trash)
  const trashRes = await fetch(`${BASE_URL}/files/${createdLinkId}/trash`, {
    method: 'POST',
    headers: authHeaders,
  });
  assert(trashRes.status === 200, 'Moving file to Trash succeeds');

  const listTrashRes = await fetch(`${BASE_URL}/trash`, {
    headers: authHeaders,
  });
  assert(listTrashRes.status === 200, 'List trash succeeds');
  const trashList = (await listTrashRes.json()).data;
  assert(Array.isArray(trashList), 'Trash is an array');
  assert(trashList.some((f) => f.id === createdLinkId), 'Trashed link appears in Trash view');

  // 12. Restore the file from Trash (POST /files/:id/restore)
  const restoreRes = await fetch(`${BASE_URL}/files/${createdLinkId}/restore`, {
    method: 'POST',
    headers: authHeaders,
  });
  assert(restoreRes.status === 200, 'Restoring file from Trash succeeds');

  // 13. Generate a secure Share Link (POST /share)
  // Schema: { fileId, permission, expiresInDays? }
  const shareRes = await fetch(`${BASE_URL}/share`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      fileId: createdNoteId,
      permission: 'DOWNLOAD',
      expiresInDays: 3,
    }),
  });
  if (shareRes.status !== 201) {
    console.error('Create share link error:', await shareRes.text());
  }
  assert(shareRes.status === 201, 'Creating public Share Link succeeds');
  const shareData = (await shareRes.json()).data;
  shareToken = shareData.token;
  assert(!!shareToken, 'Share token generated');
  console.log(`   Share URL: /share/${shareToken}`);

  // 14. Resolve the Share Link publicly (POST /share/resolve/:token, body: { password?: string })
  const publicRes = await fetch(`${BASE_URL}/share/resolve/${shareToken}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({}),
  });
  if (publicRes.status !== 200) {
    console.error('Resolve share error:', await publicRes.text());
  }
  assert(publicRes.status === 200, 'Public resolution of Share Link succeeds without auth');
  const publicData = (await publicRes.json()).data;
  assert(
    publicData.file?.name === 'System_Architecture_Notes' || publicData.file?.name === 'System Architecture Notes',
    'Publicly resolved target file name matches'
  );

  // 15. Fetch Storage Statistics (GET /storage)
  // Response: { totalUsedBytes, storageLimitBytes, usagePercentage, breakdown: {...} }
  const storageRes = await fetch(`${BASE_URL}/storage`, {
    headers: authHeaders,
  });
  assert(storageRes.status === 200, 'Storage usage overview succeeds');
  const storageStats = (await storageRes.json()).data;
  assert(typeof storageStats.totalUsedBytes === 'string', 'Storage totalUsedBytes is present');
  assert(typeof storageStats.usagePercentage === 'number', 'Storage usagePercentage is present');
  console.log(`   Storage Used: ${storageStats.totalUsedBytes} bytes of ${storageStats.storageLimitBytes} bytes (${storageStats.usagePercentage}%)`);

  console.log('\n🎉 ALL 15 END-TO-END TESTS PASSED CLEANLY!\n');
}

runE2ETests().catch((err) => {
  console.error('Fatal error during E2E test:', err);
  process.exit(1);
});
