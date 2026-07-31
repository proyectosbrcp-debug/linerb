import assert from 'node:assert/strict';
import test from 'node:test';
import { initializeApp, deleteApp } from 'firebase/app';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
  signInWithEmailAndPassword,
  signOut,
} from 'firebase/auth';

const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
const app = initializeApp(
  {
    apiKey: 'demo-linerb-auth-emulator',
    projectId: 'linerb',
    authDomain: 'linerb.local',
  },
  `auth-emulator-${Date.now()}`,
);
const auth = getAuth(app);
connectAuthEmulator(auth, `http://${authHost}`, { disableWarnings: true });

test.after(async () => {
  await signOut(auth).catch(() => {});
  await deleteApp(app);
});

test('Auth Emulator permite crear, iniciar sesión y cerrar sesión sin producción', async () => {
  const email = `inspector-${Date.now()}@linerb.local`;
  const password = 'Test1234!';

  const created = await createUserWithEmailAndPassword(auth, email, password);
  assert.ok(created.user.uid);
  assert.equal(created.user.email, email);

  await signOut(auth);
  assert.equal(auth.currentUser, null);

  const signedIn = await signInWithEmailAndPassword(auth, email, password);
  assert.equal(signedIn.user.uid, created.user.uid);
  assert.equal(signedIn.user.email, email);
});
