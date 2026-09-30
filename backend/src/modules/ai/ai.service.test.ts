import assert from 'node:assert/strict';
import test from 'node:test';
import { cosineSimilarity, filterAccessibleSpaceIds } from './ai.service';

test('semantic similarity ranks aligned vectors above unrelated vectors', () => {
  assert.equal(cosineSimilarity([1, 0], [1, 0]), 1);
  assert.equal(cosineSimilarity([1, 0], [0, 1]), 0);
  assert.equal(cosineSimilarity([1, 0], [-1, 0]), -1);
});

test('requested Space filters cannot add inaccessible Space IDs', () => {
  assert.deepEqual(
    filterAccessibleSpaceIds(['owned-space', 'shared-space'], ['shared-space', 'other-users-space']),
    ['shared-space'],
  );
});

test('omitted Space filters return only the previously authorized IDs', () => {
  assert.deepEqual(filterAccessibleSpaceIds(['owned-space', 'shared-space'], []), [
    'owned-space',
    'shared-space',
  ]);
});