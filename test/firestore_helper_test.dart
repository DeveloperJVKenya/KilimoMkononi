import 'package:flutter_test/flutter_test.dart';

import 'package:kilimomkononi/utils/firestore_helper.dart';

void main() {
  group('parseClassIdForFirestore — Format A (underscore)', () {
    test('simple school name', () {
      expect(parseClassIdForFirestore('greenwood_junior_7'),
          ('greenwood', 'junior', '7'));
    });

    test('school name containing underscores', () {
      expect(parseClassIdForFirestore('st_marys_senior_10'),
          ('st_marys', 'senior', '10'));
    });

    test('8-4-4 and primary systems', () {
      expect(parseClassIdForFirestore('greenwood_eightfourfour_3'),
          ('greenwood', 'eightfourfour', '3'));
      expect(parseClassIdForFirestore('greenwood_primary_2'),
          ('greenwood', 'primary', '2'));
    });

    test('system keyword is case-insensitive', () {
      expect(parseClassIdForFirestore('greenwood_Junior_7'),
          ('greenwood', 'junior', '7'));
    });

    test('unknown system or too few segments is unparseable', () {
      expect(parseClassIdForFirestore('greenwood_college_7'), ('', '', ''));
      expect(parseClassIdForFirestore('junior_7'), ('', '', ''));
      expect(parseClassIdForFirestore(''), ('', '', ''));
    });
  });

  group('parseClassIdForFirestore — Format B (pipe)', () {
    test('maps system keys to Firestore segments, no school', () {
      expect(parseClassIdForFirestore('7|cbcJunior'), ('', 'junior', '7'));
      expect(parseClassIdForFirestore('10|cbcSenior'), ('', 'senior', '10'));
      expect(parseClassIdForFirestore('2|cbcPrimary'), ('', 'primary', '2'));
      expect(parseClassIdForFirestore('3|eightFourFour'),
          ('', 'eightfourfour', '3'));
    });
  });

  group('parseClassIdWithSchool', () {
    test('Format A ignores the supplied school name', () {
      expect(parseClassIdWithSchool('st_marys_senior_10', 'Other School'),
          ('st_marys', 'senior', '10'));
    });

    test('Format B uses the supplied, normalized school name', () {
      expect(parseClassIdWithSchool('10|cbcSenior', ' St Marys '),
          ('St_Marys', 'senior', '10'));
    });

    test('unparseable input stays empty', () {
      expect(parseClassIdWithSchool('garbage', 'School'), ('', '', ''));
    });
  });

  test('extractSchoolName gives a human-readable label', () {
    expect(extractSchoolName('st_marys_senior_10'), 'st marys');
  });
}
