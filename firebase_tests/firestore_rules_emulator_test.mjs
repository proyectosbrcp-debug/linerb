import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'linerb';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const [host, portText] = firestoreHost.split(':');
const testEnv = await initializeTestEnvironment({
  projectId,
  firestore: {
    host,
    port: Number(portText ?? 8080),
    rules: fs.readFileSync('../firestore.rules', 'utf8'),
  },
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

test('A. usuario no autenticado no accede a datos operativos', async () => {
  await seedBaseData();
  const db = testEnv.unauthenticatedContext().firestore();

  await assertFails(getDoc(doc(db, 'users/viewer')));
  await assertFails(getDoc(doc(db, 'inspections/i-seeded')));
  await assertFails(setDoc(doc(db, 'inspections/i-new'), inspection('anon')));
  await assertFails(updateDoc(doc(db, 'inspections/i-seeded'), { linea: 'X' }));
  await assertFails(deleteDoc(doc(db, 'inspections/i-seeded')));
  await assertFails(getDoc(doc(db, 'findings/f-seeded')));
  await assertFails(setDoc(doc(db, 'findings/f-new'), finding('anon')));
});

test('B. viewer activo solo puede leer', async () => {
  await seedBaseData();
  const db = testEnv.authenticatedContext('viewer').firestore();

  await assertSucceeds(getDoc(doc(db, 'users/viewer')));
  await assertSucceeds(getDoc(doc(db, 'inspections/i-seeded')));
  await assertSucceeds(getDoc(doc(db, 'findings/f-seeded')));
  await assertFails(setDoc(doc(db, 'inspections/i-viewer'), inspection('viewer')));
  await assertFails(updateDoc(doc(db, 'inspections/i-seeded'), { linea: 'X' }));
  await assertFails(deleteDoc(doc(db, 'inspections/i-seeded')));
  await assertFails(setDoc(doc(db, 'findings/f-viewer'), finding('viewer')));
  await assertFails(updateDoc(doc(db, 'users/viewer'), { display_name: 'Otro' }));
  await assertFails(updateDoc(doc(db, 'users/viewer'), { role: 'administrator' }));
});

test('C. inspector crea datos estructurados válidos y no administra', async () => {
  await seedBaseData();
  const db = testEnv.authenticatedContext('inspector').firestore();

  await assertSucceeds(getDoc(doc(db, 'users/inspector')));
  await assertSucceeds(
    setDoc(doc(db, 'inspections/i-inspector'), inspection('inspector')),
  );
  await assertSucceeds(
    setDoc(doc(db, 'findings/f-inspector'), finding('inspector')),
  );
  await assertFails(
    setDoc(doc(db, 'inspections/i-spoofed'), inspection('administrator')),
  );
  await assertFails(
    setDoc(doc(db, 'inspections/i-extra'), {
      ...inspection('inspector'),
      photo_path: '/tmp/photo.jpg',
    }),
  );
  await assertFails(setDoc(doc(db, 'users/created-by-inspector'), profile('x')));
  await assertFails(updateDoc(doc(db, 'users/inspector'), { role: 'administrator' }));
  await assertFails(
    setDoc(doc(db, 'findings/f-photo'), {
      ...finding('inspector'),
      imageBytes: 'base64-data',
    }),
  );
});

test('D. supervisor crea y actualiza datos estructurados sin administrar perfiles', async () => {
  await seedBaseData();
  const db = testEnv.authenticatedContext('supervisor').firestore();

  await assertSucceeds(
    setDoc(doc(db, 'inspections/i-supervisor'), inspection('supervisor')),
  );
  await assertSucceeds(
    updateDoc(doc(db, 'inspections/i-seeded'), {
      updated_by: 'supervisor',
      observacion_general: 'Actualizada',
    }),
  );
  await assertSucceeds(
    updateDoc(doc(db, 'findings/f-seeded'), {
      updated_by: 'supervisor',
      descripcion: 'Actualizada',
    }),
  );
  await assertFails(updateDoc(doc(db, 'users/supervisor'), { role: 'administrator' }));
  await assertFails(setDoc(doc(db, 'users/supervisor-created'), profile('x')));
  await assertFails(
    setDoc(doc(db, 'inspections/i-supervisor-extra'), {
      ...inspection('supervisor'),
      pdfPath: '/tmp/linerb.pdf',
    }),
  );
  await assertFails(deleteDoc(doc(db, 'inspections/i-seeded')));
});

test('E. administrator administra perfiles válidos y datos estructurados', async () => {
  await seedBaseData();
  const db = testEnv.authenticatedContext('administrator').firestore();

  await assertSucceeds(getDoc(doc(db, 'users/viewer')));
  await assertSucceeds(
    setDoc(doc(db, 'users/new-viewer'), profile('new-viewer', 'viewer')),
  );
  await assertSucceeds(updateDoc(doc(db, 'users/viewer'), { active: false }));
  await assertSucceeds(updateDoc(doc(db, 'users/viewer'), { role: 'supervisor' }));
  await assertFails(
    setDoc(doc(db, 'users/bad-role'), profile('bad-role', 'owner')),
  );
  await assertFails(
    setDoc(doc(db, 'users/with-password'), {
      ...profile('with-password'),
      password: 'nope',
    }),
  );
  await assertFails(updateDoc(doc(db, 'users/administrator'), { role: 'viewer' }));
  await assertSucceeds(
    setDoc(doc(db, 'inspections/i-admin'), inspection('administrator')),
  );
  await assertSucceeds(
    setDoc(doc(db, 'findings/f-admin'), finding('administrator')),
  );
});

test('F. usuario inactivo no conserva permisos de rol anterior', async () => {
  await seedBaseData();
  const db = testEnv.authenticatedContext('inactive-inspector').firestore();

  await assertFails(getDoc(doc(db, 'inspections/i-seeded')));
  await assertFails(setDoc(doc(db, 'inspections/i-inactive'), inspection('inactive-inspector')));
  await assertFails(getDoc(doc(db, 'findings/f-seeded')));
  await assertFails(setDoc(doc(db, 'findings/f-inactive'), finding('inactive-inspector')));
});

test('G. perfil inexistente no accede a datos operativos', async () => {
  await seedBaseData();
  const db = testEnv.authenticatedContext('missing-profile').firestore();

  await assertFails(getDoc(doc(db, 'inspections/i-seeded')));
  await assertFails(setDoc(doc(db, 'inspections/i-missing'), inspection('missing-profile')));
  await assertFails(getDoc(doc(db, 'findings/f-seeded')));
});

test('campos prohibidos remotos son rechazados expresamente', async () => {
  await seedBaseData();
  const db = testEnv.authenticatedContext('inspector').firestore();
  const forbidden = [
    'photo1LocalPath',
    'photo2LocalPath',
    'photo_path',
    'image',
    'images',
    'imageBytes',
    'base64',
    'pdf',
    'pdfPath',
    'localPdfPath',
    'draft',
    'draftData',
    'password',
    'token',
  ];

  for (const field of forbidden) {
    await assertFails(
      setDoc(doc(db, `inspections/forbidden-${field}`), {
        ...inspection('inspector'),
        [field]: 'forbidden',
      }),
    );
    await assertFails(
      setDoc(doc(db, `findings/forbidden-${field}`), {
        ...finding('inspector'),
        [field]: 'forbidden',
      }),
    );
  }
});

test('matriz base de permisos fue ejercitada', () => {
  assert.equal(projectId, 'linerb');
});

async function seedBaseData() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, 'users/administrator'), profile('administrator', 'administrator')),
      setDoc(doc(db, 'users/supervisor'), profile('supervisor', 'supervisor')),
      setDoc(doc(db, 'users/inspector'), profile('inspector', 'inspector')),
      setDoc(doc(db, 'users/viewer'), profile('viewer', 'viewer')),
      setDoc(
        doc(db, 'users/inactive-inspector'),
        profile('inactive-inspector', 'inspector', false),
      ),
      setDoc(doc(db, 'inspections/i-seeded'), inspection('administrator')),
      setDoc(doc(db, 'findings/f-seeded'), finding('administrator')),
    ]);
  });
}

function profile(uid, role = 'viewer', active = true) {
  return {
    uid,
    display_name: `Usuario ${uid}`,
    email: `${uid}@linerb.test`,
    role,
    active,
    created_at: Timestamp.fromDate(new Date('2026-01-01T00:00:00Z')),
    updated_at: Timestamp.fromDate(new Date('2026-01-02T00:00:00Z')),
  };
}

function inspection(uid) {
  return {
    global_id: `inspection-${uid}`,
    fecha: Timestamp.fromDate(new Date('2026-01-03T00:00:00Z')),
    responsable: `Usuario ${uid}`,
    usuario: uid,
    tipo_linea: 'Troncal',
    linea: 'TRONCAL 1 / SUB-TRONCAL 1A',
    subtroncal: 'SUB-TRONCAL 1A',
    punto_referencia: 'KM 1',
    estado_linea: 'Operativa',
    observacion_general: 'Sin novedad',
    created_at: Timestamp.fromDate(new Date('2026-01-03T00:00:00Z')),
    updated_at: Timestamp.fromDate(new Date('2026-01-03T00:00:00Z')),
    created_by: uid,
    updated_by: uid,
    device_id: 'device-test',
    local_version: 1,
    remote_version: 0,
    sync_status: 'pendingCreate',
    deleted_at: null,
  };
}

function finding(uid) {
  return {
    global_id: `finding-${uid}`,
    inspection_global_id: `inspection-${uid}`,
    categoria: 'Fuga',
    subcategoria: 'Activa',
    descripcion: 'Detalle estructurado',
    latitud: '4.1',
    longitud: '-73.1',
    created_at: Timestamp.fromDate(new Date('2026-01-03T00:00:00Z')),
    updated_at: Timestamp.fromDate(new Date('2026-01-03T00:00:00Z')),
    created_by: uid,
    updated_by: uid,
    device_id: 'device-test',
    local_version: 1,
    remote_version: 0,
    deleted_at: null,
  };
}
