import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Data Models ---
class ZoneCity {
  final String id;
  final String name;
  ZoneCity({required this.id, required this.name});
}

class ZoneState {
  final String id;
  final String name;
  final List<ZoneCity> cities;
  ZoneState({required this.id, required this.name, required this.cities});
}

class ZoneCountry {
  final String id;
  final String name;
  final List<ZoneState> states;
  ZoneCountry({required this.id, required this.name, required this.states});
}

// --- Mock Data ---
const List<ZoneCountry> mockDeliveryData = [
  ZoneCountry(
    id: 'country_in',
    name: 'India',
    states: [
      ZoneState(
        id: 'state_in_1',
        name: 'Andhra Pradesh',
        cities: [
          ZoneCity(id: 'city_in_1_1', name: 'Visakhapatnam'),
          ZoneCity(id: 'city_in_1_2', name: 'Vijayawada'),
          ZoneCity(id: 'city_in_1_3', name: 'Guntur'),
          ZoneCity(id: 'city_in_1_4', name: 'Nellore'),
          ZoneCity(id: 'city_in_1_5', name: 'Kurnool'),
          ZoneCity(id: 'city_in_1_6', name: 'Kadapa'),
          ZoneCity(id: 'city_in_1_7', name: 'Anantapur'),
          ZoneCity(id: 'city_in_1_8', name: 'Chittoor'),
          ZoneCity(id: 'city_in_1_9', name: 'East Godavari'),
          ZoneCity(id: 'city_in_1_10', name: 'West Godavari'),
          ZoneCity(id: 'city_in_1_11', name: 'Srikakulam'),
          ZoneCity(id: 'city_in_1_12', name: 'Vizianagaram'),
          ZoneCity(id: 'city_in_1_13', name: 'Prakasam'),
          ZoneCity(id: 'city_in_1_14', name: 'Sri Potti Sriramulu Nellore'),
          ZoneCity(id: 'city_in_1_15', name: 'Eluru'),
          ZoneCity(id: 'city_in_1_16', name: 'Bapatla'),
          ZoneCity(id: 'city_in_1_17', name: 'Parvathipuram Manyam'),
          ZoneCity(id: 'city_in_1_18', name: 'Alluri Sitharama Raju'),
          ZoneCity(id: 'city_in_1_19', name: 'Anakapalli'),
          ZoneCity(id: 'city_in_1_20', name: 'Konaseema'),
          ZoneCity(id: 'city_in_1_21', name: 'NTR District'),
          ZoneCity(id: 'city_in_1_22', name: 'Sri Sathya Sai'),
          ZoneCity(id: 'city_in_1_23', name: 'Tirupati'),
        ],
      ),
      ZoneState(
        id: 'state_in_2',
        name: 'Arunachal Pradesh',
        cities: [
          ZoneCity(id: 'city_in_2_1', name: 'Itanagar'),
          ZoneCity(id: 'city_in_2_2', name: 'Tawang'),
          ZoneCity(id: 'city_in_2_3', name: 'West Kameng'),
          ZoneCity(id: 'city_in_2_4', name: 'East Kameng'),
          ZoneCity(id: 'city_in_2_5', name: 'Papum Pare'),
          ZoneCity(id: 'city_in_2_6', name: 'Kurung Kumey'),
          ZoneCity(id: 'city_in_2_7', name: 'Lower Subansiri'),
          ZoneCity(id: 'city_in_2_8', name: 'Upper Subansiri'),
          ZoneCity(id: 'city_in_2_9', name: 'West Siang'),
          ZoneCity(id: 'city_in_2_10', name: 'East Siang'),
          ZoneCity(id: 'city_in_2_11', name: 'Upper Siang'),
          ZoneCity(id: 'city_in_2_12', name: 'Dibang Valley'),
          ZoneCity(id: 'city_in_2_13', name: 'Lower Dibang Valley'),
          ZoneCity(id: 'city_in_2_14', name: 'Lohit'),
          ZoneCity(id: 'city_in_2_15', name: 'Namsai'),
          ZoneCity(id: 'city_in_2_16', name: 'Anjaw'),
          ZoneCity(id: 'city_in_2_17', name: 'Changlang'),
          ZoneCity(id: 'city_in_2_18', name: 'Tirap'),
          ZoneCity(id: 'city_in_2_19', name: 'Longding'),
          ZoneCity(id: 'city_in_2_20', name: 'Pakke Kessang'),
          ZoneCity(id: 'city_in_2_21', name: 'Kamle'),
          ZoneCity(id: 'city_in_2_22', name: 'Shi Yomi'),
          ZoneCity(id: 'city_in_2_23', name: 'Kra Daadi'),
          ZoneCity(id: 'city_in_2_24', name: 'Lepa Rada'),
          ZoneCity(id: 'city_in_2_25', name: 'Siang'),
        ],
      ),
      ZoneState(
        id: 'state_in_3',
        name: 'Assam',
        cities: [
          ZoneCity(id: 'city_in_3_1', name: 'Guwahati'),
          ZoneCity(id: 'city_in_3_2', name: 'Kokrajhar'),
          ZoneCity(id: 'city_in_3_3', name: 'Chirang'),
          ZoneCity(id: 'city_in_3_4', name: 'Bongaigaon'),
          ZoneCity(id: 'city_in_3_5', name: 'Barpeta'),
          ZoneCity(id: 'city_in_3_6', name: 'Nalbari'),
          ZoneCity(id: 'city_in_3_7', name: 'Kamrup'),
          ZoneCity(id: 'city_in_3_8', name: 'Darrang'),
          ZoneCity(id: 'city_in_3_9', name: 'Sonitpur'),
          ZoneCity(id: 'city_in_3_10', name: 'Udalguri'),
          ZoneCity(id: 'city_in_3_11', name: 'Baksa'),
          ZoneCity(id: 'city_in_3_12', name: 'Biswanath'),
          ZoneCity(id: 'city_in_3_13', name: 'Majuli'),
          ZoneCity(id: 'city_in_3_14', name: 'Lakhimpur'),
          ZoneCity(id: 'city_in_3_15', name: 'Dhemaji'),
          ZoneCity(id: 'city_in_3_16', name: 'Tinsukia'),
          ZoneCity(id: 'city_in_3_17', name: 'Dibrugarh'),
          ZoneCity(id: 'city_in_3_18', name: 'Sibsagar'),
          ZoneCity(id: 'city_in_3_19', name: 'Charaideo'),
          ZoneCity(id: 'city_in_3_20', name: 'Jorhat'),
          ZoneCity(id: 'city_in_3_21', name: 'Golaghat'),
          ZoneCity(id: 'city_in_3_22', name: 'Nagaon'),
          ZoneCity(id: 'city_in_3_23', name: 'Hojai'),
          ZoneCity(id: 'city_in_3_24', name: 'West Karbi Anglong'),
          ZoneCity(id: 'city_in_3_25', name: 'Karbi Anglong'),
          ZoneCity(id: 'city_in_3_26', name: 'East Karbi Anglong'),
          ZoneCity(id: 'city_in_3_27', name: 'Dima Hasao'),
          ZoneCity(id: 'city_in_3_28', name: 'Cachar'),
          ZoneCity(id: 'city_in_3_29', name: 'Hailakandi'),
          ZoneCity(id: 'city_in_3_30', name: 'Karimganj'),
          ZoneCity(id: 'city_in_3_31', name: 'Morigaon'),
          ZoneCity(id: 'city_in_3_32', name: 'Goalpara'),
          ZoneCity(id: 'city_in_3_33', name: 'Dhubri'),
          ZoneCity(id: 'city_in_3_34', name: 'South Salmara'),
          ZoneCity(id: 'city_in_3_35', name: 'Bajali'),
          ZoneCity(id: 'city_in_3_36', name: 'Tamulpur'),
        ],
      ),
      ZoneState(
        id: 'state_in_4',
        name: 'Bihar',
        cities: [
          ZoneCity(id: 'city_in_4_1', name: 'Patna'),
          ZoneCity(id: 'city_in_4_2', name: 'Nalanda'),
          ZoneCity(id: 'city_in_4_3', name: 'Bhojpur'),
          ZoneCity(id: 'city_in_4_4', name: 'Saran'),
          ZoneCity(id: 'city_in_4_5', name: 'Siwan'),
          ZoneCity(id: 'city_in_4_6', name: 'Gopalganj'),
          ZoneCity(id: 'city_in_4_7', name: 'East Champaran'),
          ZoneCity(id: 'city_in_4_8', name: 'West Champaran'),
          ZoneCity(id: 'city_in_4_9', name: 'Sitamarhi'),
          ZoneCity(id: 'city_in_4_10', name: 'Sheohar'),
          ZoneCity(id: 'city_in_4_11', name: 'Muzaffarpur'),
          ZoneCity(id: 'city_in_4_12', name: 'Vaishali'),
          ZoneCity(id: 'city_in_4_13', name: 'Darbhanga'),
          ZoneCity(id: 'city_in_4_14', name: 'Madhubani'),
          ZoneCity(id: 'city_in_4_15', name: 'Samastipur'),
          ZoneCity(id: 'city_in_4_16', name: 'Begusarai'),
          ZoneCity(id: 'city_in_4_17', name: 'Khagaria'),
          ZoneCity(id: 'city_in_4_18', name: 'Bhagalpur'),
          ZoneCity(id: 'city_in_4_19', name: 'Banka'),
          ZoneCity(id: 'city_in_4_20', name: 'Supaul'),
          ZoneCity(id: 'city_in_4_21', name: 'Saharsa'),
          ZoneCity(id: 'city_in_4_22', name: 'Madhepura'),
          ZoneCity(id: 'city_in_4_23', name: 'Purnia'),
          ZoneCity(id: 'city_in_4_24', name: 'Araria'),
          ZoneCity(id: 'city_in_4_25', name: 'Kishanganj'),
          ZoneCity(id: 'city_in_4_26', name: 'Katihar'),
          ZoneCity(id: 'city_in_4_27', name: 'Munger'),
          ZoneCity(id: 'city_in_4_28', name: 'Sheikhpura'),
          ZoneCity(id: 'city_in_4_29', name: 'Lakhisarai'),
          ZoneCity(id: 'city_in_4_30', name: 'Jamui'),
          ZoneCity(id: 'city_in_4_31', name: 'Nawada'),
          ZoneCity(id: 'city_in_4_32', name: 'Gaya'),
          ZoneCity(id: 'city_in_4_33', name: 'Aurangabad'),
          ZoneCity(id: 'city_in_4_34', name: 'Rohtas'),
          ZoneCity(id: 'city_in_4_35', name: 'Kaimur'),
          ZoneCity(id: 'city_in_4_36', name: 'Jehanabad'),
          ZoneCity(id: 'city_in_4_37', name: 'Arwal'),
          ZoneCity(id: 'city_in_4_38', name: 'Buxar'),
        ],
      ),
      ZoneState(
        id: 'state_in_5',
        name: 'Chhattisgarh',
        cities: [
          ZoneCity(id: 'city_in_5_1', name: 'Raipur'),
          ZoneCity(id: 'city_in_5_2', name: 'Bilaspur'),
          ZoneCity(id: 'city_in_5_3', name: 'Durg'),
          ZoneCity(id: 'city_in_5_4', name: 'Rajnandgaon'),
          ZoneCity(id: 'city_in_5_5', name: 'Kawardha'),
          ZoneCity(id: 'city_in_5_6', name: 'Balod'),
          ZoneCity(id: 'city_in_5_7', name: 'Gariaband'),
          ZoneCity(id: 'city_in_5_8', name: 'Mahasamund'),
          ZoneCity(id: 'city_in_5_9', name: 'Baloda Bazar'),
          ZoneCity(id: 'city_in_5_10', name: 'Janjgir-Champa'),
          ZoneCity(id: 'city_in_5_11', name: 'Raigarh'),
          ZoneCity(id: 'city_in_5_12', name: 'Surguja'),
          ZoneCity(id: 'city_in_5_13', name: 'Surajpur'),
          ZoneCity(id: 'city_in_5_14', name: 'Koriya'),
          ZoneCity(id: 'city_in_5_15', name: 'Balrampur'),
          ZoneCity(id: 'city_in_5_16', name: 'Jashpur'),
          ZoneCity(id: 'city_in_5_17', name: 'Korba'),
          ZoneCity(id: 'city_in_5_18', name: 'Mungeli'),
          ZoneCity(id: 'city_in_5_19', name: 'Kondagaon'),
          ZoneCity(id: 'city_in_5_20', name: 'Narayanpur'),
          ZoneCity(id: 'city_in_5_21', name: 'Dantewada'),
          ZoneCity(id: 'city_in_5_22', name: 'Sukma'),
          ZoneCity(id: 'city_in_5_23', name: 'Bijapur'),
          ZoneCity(id: 'city_in_5_24', name: 'Bastar'),
          ZoneCity(id: 'city_in_5_25', name: 'Kanker'),
          ZoneCity(id: 'city_in_5_26', name: 'Bemetara'),
          ZoneCity(id: 'city_in_5_27', name: 'Gaurela-Pendra'),
          ZoneCity(id: 'city_in_5_28', name: 'Sakti'),
          ZoneCity(id: 'city_in_5_29', name: 'Manendragarh'),
          ZoneCity(id: 'city_in_5_30', name: 'Sarangarh-Bilaigarh'),
          ZoneCity(id: 'city_in_5_31', name: 'Khairagarh'),
          ZoneCity(id: 'city_in_5_32', name: 'Mohla-Manpur'),
          ZoneCity(id: 'city_in_5_33', name: 'Shakti'),
        ],
      ),
      ZoneState(
        id: 'state_in_6',
        name: 'Goa',
        cities: [
          ZoneCity(id: 'city_in_6_1', name: 'Panaji'),
          ZoneCity(id: 'city_in_6_2', name: 'Margao'),
        ],
      ),
      ZoneState(
        id: 'state_in_7',
        name: 'Gujarat',
        cities: [
          ZoneCity(id: 'city_in_7_1', name: 'Ahmedabad'),
          ZoneCity(id: 'city_in_7_2', name: 'Surat'),
          ZoneCity(id: 'city_in_7_3', name: 'Vadodara'),
          ZoneCity(id: 'city_in_7_4', name: 'Rajkot'),
          ZoneCity(id: 'city_in_7_5', name: 'Bhavnagar'),
          ZoneCity(id: 'city_in_7_6', name: 'Jamnagar'),
          ZoneCity(id: 'city_in_7_7', name: 'Junagadh'),
          ZoneCity(id: 'city_in_7_8', name: 'Amreli'),
          ZoneCity(id: 'city_in_7_9', name: 'Porbandar'),
          ZoneCity(id: 'city_in_7_10', name: 'Gir Somnath'),
          ZoneCity(id: 'city_in_7_11', name: 'Kutch'),
          ZoneCity(id: 'city_in_7_12', name: 'Patan'),
          ZoneCity(id: 'city_in_7_13', name: 'Mehsana'),
          ZoneCity(id: 'city_in_7_14', name: 'Banaskantha'),
          ZoneCity(id: 'city_in_7_15', name: 'Sabarkantha'),
          ZoneCity(id: 'city_in_7_16', name: 'Aravalli'),
          ZoneCity(id: 'city_in_7_17', name: 'Gandhinagar'),
          ZoneCity(id: 'city_in_7_18', name: 'Kheda'),
          ZoneCity(id: 'city_in_7_19', name: 'Anand'),
          ZoneCity(id: 'city_in_7_20', name: 'Panchmahal'),
          ZoneCity(id: 'city_in_7_21', name: 'Dahod'),
          ZoneCity(id: 'city_in_7_22', name: 'Chhota Udaipur'),
          ZoneCity(id: 'city_in_7_23', name: 'Narmada'),
          ZoneCity(id: 'city_in_7_24', name: 'Bharuch'),
          ZoneCity(id: 'city_in_7_25', name: 'Navsari'),
          ZoneCity(id: 'city_in_7_26', name: 'Valsad'),
          ZoneCity(id: 'city_in_7_27', name: 'Tapi'),
          ZoneCity(id: 'city_in_7_28', name: 'Dang'),
          ZoneCity(id: 'city_in_7_29', name: 'Dwarka'),
          ZoneCity(id: 'city_in_7_30', name: 'Morbi'),
          ZoneCity(id: 'city_in_7_31', name: 'Botad'),
          ZoneCity(id: 'city_in_7_32', name: 'Mahisagar'),
          ZoneCity(id: 'city_in_7_33', name: 'Mundra'),
          ZoneCity(id: 'city_in_7_34', name: 'Kandla'),
        ],
      ),
      ZoneState(
        id: 'state_in_8',
        name: 'Haryana',
        cities: [
          ZoneCity(id: 'city_in_8_1', name: 'Chandigarh'),
          ZoneCity(id: 'city_in_8_2', name: 'Faridabad'),
          ZoneCity(id: 'city_in_8_3', name: 'Gurugram'),
          ZoneCity(id: 'city_in_8_4', name: 'Ambala'),
          ZoneCity(id: 'city_in_8_5', name: 'Hisar'),
          ZoneCity(id: 'city_in_8_6', name: 'Rohtak'),
          ZoneCity(id: 'city_in_8_7', name: 'Panipat'),
          ZoneCity(id: 'city_in_8_8', name: 'Sonipat'),
          ZoneCity(id: 'city_in_8_9', name: 'Karnal'),
          ZoneCity(id: 'city_in_8_10', name: 'Kurukshetra'),
          ZoneCity(id: 'city_in_8_11', name: 'Yamunanagar'),
          ZoneCity(id: 'city_in_8_12', name: 'Jhajjar'),
          ZoneCity(id: 'city_in_8_13', name: 'Rewari'),
          ZoneCity(id: 'city_in_8_14', name: 'Mahendragarh'),
          ZoneCity(id: 'city_in_8_15', name: 'Bhiwani'),
          ZoneCity(id: 'city_in_8_16', name: 'Charkhi Dadri'),
          ZoneCity(id: 'city_in_8_17', name: 'Jind'),
          ZoneCity(id: 'city_in_8_18', name: 'Kaithal'),
          ZoneCity(id: 'city_in_8_19', name: 'Fatehabad'),
          ZoneCity(id: 'city_in_8_20', name: 'Sirsa'),
          ZoneCity(id: 'city_in_8_21', name: 'Panchkula'),
          ZoneCity(id: 'city_in_8_22', name: 'Palwal'),
          ZoneCity(id: 'city_in_8_23', name: 'Nuh'),
        ],
      ),
      ZoneState(
        id: 'state_in_9',
        name: 'Himachal Pradesh',
        cities: [
          ZoneCity(id: 'city_in_9_1', name: 'Shimla'),
          ZoneCity(id: 'city_in_9_2', name: 'Kangra'),
          ZoneCity(id: 'city_in_9_3', name: 'Mandi'),
          ZoneCity(id: 'city_in_9_4', name: 'Solan'),
          ZoneCity(id: 'city_in_9_5', name: 'Sirmaur'),
          ZoneCity(id: 'city_in_9_6', name: 'Kullu'),
          ZoneCity(id: 'city_in_9_7', name: 'Hamirpur'),
          ZoneCity(id: 'city_in_9_8', name: 'Una'),
          ZoneCity(id: 'city_in_9_9', name: 'Bilaspur'),
          ZoneCity(id: 'city_in_9_10', name: 'Chamba'),
          ZoneCity(id: 'city_in_9_11', name: 'Kinnaur'),
          ZoneCity(id: 'city_in_9_12', name: 'Lahaul Spiti'),
        ],
      ),
      ZoneState(
        id: 'state_in_10',
        name: 'Jharkhand',
        cities: [
          ZoneCity(id: 'city_in_10_1', name: 'Ranchi'),
          ZoneCity(id: 'city_in_10_2', name: 'Dhanbad'),
          ZoneCity(id: 'city_in_10_3', name: 'Jamshedpur'),
          ZoneCity(id: 'city_in_10_4', name: 'Bokaro'),
          ZoneCity(id: 'city_in_10_5', name: 'Deoghar'),
          ZoneCity(id: 'city_in_10_6', name: 'Hazaribagh'),
          ZoneCity(id: 'city_in_10_7', name: 'Giridih'),
          ZoneCity(id: 'city_in_10_8', name: 'Ramgarh'),
          ZoneCity(id: 'city_in_10_9', name: 'Chatra'),
          ZoneCity(id: 'city_in_10_10', name: 'Koderma'),
          ZoneCity(id: 'city_in_10_11', name: 'Palamu'),
          ZoneCity(id: 'city_in_10_12', name: 'Latehar'),
          ZoneCity(id: 'city_in_10_13', name: 'Gumla'),
          ZoneCity(id: 'city_in_10_14', name: 'Simdega'),
          ZoneCity(id: 'city_in_10_15', name: 'Lohardaga'),
          ZoneCity(id: 'city_in_10_16', name: 'Khunti'),
          ZoneCity(id: 'city_in_10_17', name: 'Seraikela-Kharsawan'),
          ZoneCity(id: 'city_in_10_18', name: 'East Singhbhum'),
          ZoneCity(id: 'city_in_10_19', name: 'West Singhbhum'),
          ZoneCity(id: 'city_in_10_20', name: 'Sahebganj'),
          ZoneCity(id: 'city_in_10_21', name: 'Pakur'),
          ZoneCity(id: 'city_in_10_22', name: 'Godda'),
          ZoneCity(id: 'city_in_10_23', name: 'Dumka'),
          ZoneCity(id: 'city_in_10_24', name: 'Jamtara'),
        ],
      ),
      ZoneState(
        id: 'state_in_11',
        name: 'Karnataka',
        cities: [
          ZoneCity(id: 'city_in_11_1', name: 'Bengaluru'),
          ZoneCity(id: 'city_in_11_2', name: 'Mysuru'),
          ZoneCity(id: 'city_in_11_3', name: 'Mangaluru'),
          ZoneCity(id: 'city_in_11_4', name: 'Hubli-Dharwad'),
          ZoneCity(id: 'city_in_11_5', name: 'Belagavi'),
          ZoneCity(id: 'city_in_11_6', name: 'Kalaburagi'),
          ZoneCity(id: 'city_in_11_7', name: 'Ballari'),
          ZoneCity(id: 'city_in_11_8', name: 'Raichur'),
          ZoneCity(id: 'city_in_11_9', name: 'Vijayapura'),
          ZoneCity(id: 'city_in_11_10', name: 'Bagalkot'),
          ZoneCity(id: 'city_in_11_11', name: 'Gadag'),
          ZoneCity(id: 'city_in_11_12', name: 'Haveri'),
          ZoneCity(id: 'city_in_11_13', name: 'Uttara Kannada'),
          ZoneCity(id: 'city_in_11_14', name: 'Shivamogga'),
          ZoneCity(id: 'city_in_11_15', name: 'Chikkamagaluru'),
          ZoneCity(id: 'city_in_11_16', name: 'Kodagu'),
          ZoneCity(id: 'city_in_11_17', name: 'Hassan'),
          ZoneCity(id: 'city_in_11_18', name: 'Tumakuru'),
          ZoneCity(id: 'city_in_11_19', name: 'Chikkaballapura'),
          ZoneCity(id: 'city_in_11_20', name: 'Kolar'),
          ZoneCity(id: 'city_in_11_21', name: 'Ramanagara'),
          ZoneCity(id: 'city_in_11_22', name: 'Chamarajanagar'),
          ZoneCity(id: 'city_in_11_23', name: 'Mandya'),
          ZoneCity(id: 'city_in_11_24', name: 'Koppal'),
          ZoneCity(id: 'city_in_11_25', name: 'Yadgir'),
          ZoneCity(id: 'city_in_11_26', name: 'Bidar'),
          ZoneCity(id: 'city_in_11_27', name: 'Dharwad'),
          ZoneCity(id: 'city_in_11_28', name: 'Davangere'),
          ZoneCity(id: 'city_in_11_29', name: 'Chitradurga'),
          ZoneCity(id: 'city_in_11_30', name: 'Bengaluru Rural'),
          ZoneCity(id: 'city_in_11_31', name: 'Vijayanagara'),
        ],
      ),
      ZoneState(
        id: 'state_in_12',
        name: 'Kerala',
        cities: [
          ZoneCity(id: 'city_in_12_1', name: 'Thiruvananthapuram'),
          ZoneCity(id: 'city_in_12_2', name: 'Kochi'),
          ZoneCity(id: 'city_in_12_3', name: 'Kozhikode'),
          ZoneCity(id: 'city_in_12_4', name: 'Thrissur'),
          ZoneCity(id: 'city_in_12_5', name: 'Palakkad'),
          ZoneCity(id: 'city_in_12_6', name: 'Malappuram'),
          ZoneCity(id: 'city_in_12_7', name: 'Kannur'),
          ZoneCity(id: 'city_in_12_8', name: 'Kasaragod'),
          ZoneCity(id: 'city_in_12_9', name: 'Wayanad'),
          ZoneCity(id: 'city_in_12_10', name: 'Idukki'),
          ZoneCity(id: 'city_in_12_11', name: 'Ernakulam'),
          ZoneCity(id: 'city_in_12_12', name: 'Alappuzha'),
          ZoneCity(id: 'city_in_12_13', name: 'Kottayam'),
          ZoneCity(id: 'city_in_12_14', name: 'Pathanamthitta'),
          ZoneCity(id: 'city_in_12_15', name: 'Kollam'),
        ],
      ),
      ZoneState(
        id: 'state_in_13',
        name: 'Madhya Pradesh',
        cities: [
          ZoneCity(id: 'city_in_13_1', name: 'Bhopal'),
          ZoneCity(id: 'city_in_13_2', name: 'Indore'),
          ZoneCity(id: 'city_in_13_3', name: 'Jabalpur'),
          ZoneCity(id: 'city_in_13_4', name: 'Gwalior'),
          ZoneCity(id: 'city_in_13_5', name: 'Ujjain'),
          ZoneCity(id: 'city_in_13_6', name: 'Sagar'),
          ZoneCity(id: 'city_in_13_7', name: 'Rewa'),
          ZoneCity(id: 'city_in_13_8', name: 'Satna'),
          ZoneCity(id: 'city_in_13_9', name: 'Morena'),
          ZoneCity(id: 'city_in_13_10', name: 'Bhind'),
          ZoneCity(id: 'city_in_13_11', name: 'Shivpuri'),
          ZoneCity(id: 'city_in_13_12', name: 'Guna'),
          ZoneCity(id: 'city_in_13_13', name: 'Ashoknagar'),
          ZoneCity(id: 'city_in_13_14', name: 'Datia'),
          ZoneCity(id: 'city_in_13_15', name: 'Tikamgarh'),
          ZoneCity(id: 'city_in_13_16', name: 'Chhatarpur'),
          ZoneCity(id: 'city_in_13_17', name: 'Panna'),
          ZoneCity(id: 'city_in_13_18', name: 'Damoh'),
          ZoneCity(id: 'city_in_13_19', name: 'Raisen'),
          ZoneCity(id: 'city_in_13_20', name: 'Sehore'),
          ZoneCity(id: 'city_in_13_21', name: 'Vidisha'),
          ZoneCity(id: 'city_in_13_22', name: 'Rajgarh'),
          ZoneCity(id: 'city_in_13_23', name: 'Shajapur'),
          ZoneCity(id: 'city_in_13_24', name: 'Agar Malwa'),
          ZoneCity(id: 'city_in_13_25', name: 'Dewas'),
          ZoneCity(id: 'city_in_13_26', name: 'Mandsaur'),
          ZoneCity(id: 'city_in_13_27', name: 'Ratlam'),
          ZoneCity(id: 'city_in_13_28', name: 'Neemuch'),
          ZoneCity(id: 'city_in_13_29', name: 'Jhabua'),
          ZoneCity(id: 'city_in_13_30', name: 'Alirajpur'),
          ZoneCity(id: 'city_in_13_31', name: 'Barwani'),
          ZoneCity(id: 'city_in_13_32', name: 'Dhar'),
          ZoneCity(id: 'city_in_13_33', name: 'Khargone'),
          ZoneCity(id: 'city_in_13_34', name: 'Khandwa'),
          ZoneCity(id: 'city_in_13_35', name: 'Burhanpur'),
          ZoneCity(id: 'city_in_13_36', name: 'Betul'),
          ZoneCity(id: 'city_in_13_37', name: 'Hoshangabad'),
          ZoneCity(id: 'city_in_13_38', name: 'Narmadapuram'),
          ZoneCity(id: 'city_in_13_39', name: 'Harda'),
          ZoneCity(id: 'city_in_13_40', name: 'Narsinghpur'),
          ZoneCity(id: 'city_in_13_41', name: 'Chhindwara'),
          ZoneCity(id: 'city_in_13_42', name: 'Seoni'),
          ZoneCity(id: 'city_in_13_43', name: 'Mandla'),
          ZoneCity(id: 'city_in_13_44', name: 'Dindori'),
          ZoneCity(id: 'city_in_13_45', name: 'Balaghat'),
          ZoneCity(id: 'city_in_13_46', name: 'Sidhi'),
          ZoneCity(id: 'city_in_13_47', name: 'Singrauli'),
          ZoneCity(id: 'city_in_13_48', name: 'Umaria'),
          ZoneCity(id: 'city_in_13_49', name: 'Shahdol'),
          ZoneCity(id: 'city_in_13_50', name: 'Anuppur'),
          ZoneCity(id: 'city_in_13_51', name: 'Katni'),
        ],
      ),
      ZoneState(
        id: 'state_in_14',
        name: 'Maharashtra',
        cities: [
          ZoneCity(id: 'city_in_14_1', name: 'Mumbai'),
          ZoneCity(id: 'city_in_14_2', name: 'Pune'),
          ZoneCity(id: 'city_in_14_3', name: 'Nagpur'),
          ZoneCity(id: 'city_in_14_4', name: 'Nashik'),
          ZoneCity(id: 'city_in_14_5', name: 'Aurangabad'),
          ZoneCity(id: 'city_in_14_6', name: 'Solapur'),
          ZoneCity(id: 'city_in_14_7', name: 'Amravati'),
          ZoneCity(id: 'city_in_14_8', name: 'Kolhapur'),
          ZoneCity(id: 'city_in_14_9', name: 'Akola'),
          ZoneCity(id: 'city_in_14_10', name: 'Latur'),
          ZoneCity(id: 'city_in_14_11', name: 'Dhule'),
          ZoneCity(id: 'city_in_14_12', name: 'Jalgaon'),
          ZoneCity(id: 'city_in_14_13', name: 'Ahmednagar'),
          ZoneCity(id: 'city_in_14_14', name: 'Satara'),
          ZoneCity(id: 'city_in_14_15', name: 'Sangli'),
          ZoneCity(id: 'city_in_14_16', name: 'Ratnagiri'),
          ZoneCity(id: 'city_in_14_17', name: 'Sindhudurg'),
          ZoneCity(id: 'city_in_14_18', name: 'Thane'),
          ZoneCity(id: 'city_in_14_19', name: 'Raigad'),
          ZoneCity(id: 'city_in_14_20', name: 'Palghar'),
          ZoneCity(id: 'city_in_14_21', name: 'Nanded'),
          ZoneCity(id: 'city_in_14_22', name: 'Hingoli'),
          ZoneCity(id: 'city_in_14_23', name: 'Parbhani'),
          ZoneCity(id: 'city_in_14_24', name: 'Jalna'),
          ZoneCity(id: 'city_in_14_25', name: 'Beed'),
          ZoneCity(id: 'city_in_14_26', name: 'Osmanabad'),
          ZoneCity(id: 'city_in_14_27', name: 'Yavatmal'),
          ZoneCity(id: 'city_in_14_28', name: 'Wardha'),
          ZoneCity(id: 'city_in_14_29', name: 'Chandrapur'),
          ZoneCity(id: 'city_in_14_30', name: 'Gadchiroli'),
          ZoneCity(id: 'city_in_14_31', name: 'Gondia'),
          ZoneCity(id: 'city_in_14_32', name: 'Bhandara'),
          ZoneCity(id: 'city_in_14_33', name: 'Washim'),
          ZoneCity(id: 'city_in_14_34', name: 'Buldhana'),
          ZoneCity(id: 'city_in_14_35', name: 'Nandurbar'),
        ],
      ),
      ZoneState(
        id: 'state_in_15',
        name: 'Manipur',
        cities: [
          ZoneCity(id: 'city_in_15_1', name: 'Imphal'),
          ZoneCity(id: 'city_in_15_2', name: 'Bishnupur'),
          ZoneCity(id: 'city_in_15_3', name: 'Thoubal'),
          ZoneCity(id: 'city_in_15_4', name: 'Churachandpur'),
          ZoneCity(id: 'city_in_15_5', name: 'Chandel'),
          ZoneCity(id: 'city_in_15_6', name: 'Senapati'),
          ZoneCity(id: 'city_in_15_7', name: 'Ukhrul'),
          ZoneCity(id: 'city_in_15_8', name: 'Tamenglong'),
          ZoneCity(id: 'city_in_15_9', name: 'Jiribam'),
          ZoneCity(id: 'city_in_15_10', name: 'Kakching'),
          ZoneCity(id: 'city_in_15_11', name: 'Tengnoupal'),
          ZoneCity(id: 'city_in_15_12', name: 'Kamjong'),
          ZoneCity(id: 'city_in_15_13', name: 'Kangpokpi'),
          ZoneCity(id: 'city_in_15_14', name: 'Pherzawl'),
          ZoneCity(id: 'city_in_15_15', name: 'Noney'),
          ZoneCity(id: 'city_in_15_16', name: 'Imphal East'),
        ],
      ),
      ZoneState(
        id: 'state_in_16',
        name: 'Meghalaya',
        cities: [
          ZoneCity(id: 'city_in_16_1', name: 'Shillong'),
          ZoneCity(id: 'city_in_16_2', name: 'East Khasi Hills'),
          ZoneCity(id: 'city_in_16_3', name: 'West Khasi Hills'),
          ZoneCity(id: 'city_in_16_4', name: 'Ribhoi'),
          ZoneCity(id: 'city_in_16_5', name: 'East Jaintia Hills'),
          ZoneCity(id: 'city_in_16_6', name: 'West Jaintia Hills'),
          ZoneCity(id: 'city_in_16_7', name: 'East Garo Hills'),
          ZoneCity(id: 'city_in_16_8', name: 'West Garo Hills'),
          ZoneCity(id: 'city_in_16_9', name: 'South Garo Hills'),
          ZoneCity(id: 'city_in_16_10', name: 'North Garo Hills'),
          ZoneCity(id: 'city_in_16_11', name: 'Eastern West Khasi Hills'),
          ZoneCity(id: 'city_in_16_12', name: 'Mairang'),
        ],
      ),
      ZoneState(
        id: 'state_in_17',
        name: 'Mizoram',
        cities: [
          ZoneCity(id: 'city_in_17_1', name: 'Aizawl'),
          ZoneCity(id: 'city_in_17_2', name: 'Champhai'),
          ZoneCity(id: 'city_in_17_3', name: 'Kolasib'),
          ZoneCity(id: 'city_in_17_4', name: 'Lawngtlai'),
          ZoneCity(id: 'city_in_17_5', name: 'Lunglei'),
          ZoneCity(id: 'city_in_17_6', name: 'Mamit'),
          ZoneCity(id: 'city_in_17_7', name: 'Saiha'),
          ZoneCity(id: 'city_in_17_8', name: 'Serchhip'),
          ZoneCity(id: 'city_in_17_9', name: 'Hnahthial'),
          ZoneCity(id: 'city_in_17_10', name: 'Khawzawl'),
          ZoneCity(id: 'city_in_17_11', name: 'Saitual'),
        ],
      ),
      ZoneState(
        id: 'state_in_18',
        name: 'Nagaland',
        cities: [
          ZoneCity(id: 'city_in_18_1', name: 'Kohima'),
          ZoneCity(id: 'city_in_18_2', name: 'Dimapur'),
          ZoneCity(id: 'city_in_18_3', name: 'Mokokchung'),
          ZoneCity(id: 'city_in_18_4', name: 'Mon'),
          ZoneCity(id: 'city_in_18_5', name: 'Tuensang'),
          ZoneCity(id: 'city_in_18_6', name: 'Wokha'),
          ZoneCity(id: 'city_in_18_7', name: 'Zunheboto'),
          ZoneCity(id: 'city_in_18_8', name: 'Phek'),
          ZoneCity(id: 'city_in_18_9', name: 'Kiphire'),
          ZoneCity(id: 'city_in_18_10', name: 'Longleng'),
          ZoneCity(id: 'city_in_18_11', name: 'Peren'),
          ZoneCity(id: 'city_in_18_12', name: 'Niuland'),
          ZoneCity(id: 'city_in_18_13', name: 'Tseminyu'),
        ],
      ),
      ZoneState(
        id: 'state_in_19',
        name: 'Odisha',
        cities: [
          ZoneCity(id: 'city_in_19_1', name: 'Bhubaneswar'),
          ZoneCity(id: 'city_in_19_2', name: 'Cuttack'),
          ZoneCity(id: 'city_in_19_3', name: 'Rourkela'),
          ZoneCity(id: 'city_in_19_4', name: 'Paradip'),
          ZoneCity(id: 'city_in_19_5', name: 'Puri'),
          ZoneCity(id: 'city_in_19_6', name: 'Berhampur'),
          ZoneCity(id: 'city_in_19_7', name: 'Sambalpur'),
          ZoneCity(id: 'city_in_19_8', name: 'Balasore'),
          ZoneCity(id: 'city_in_19_9', name: 'Angul'),
          ZoneCity(id: 'city_in_19_10', name: 'Dhenkanal'),
          ZoneCity(id: 'city_in_19_11', name: 'Jajpur'),
          ZoneCity(id: 'city_in_19_12', name: 'Kendujhar'),
          ZoneCity(id: 'city_in_19_13', name: 'Mayurbhanj'),
          ZoneCity(id: 'city_in_19_14', name: 'Sundargarh'),
          ZoneCity(id: 'city_in_19_15', name: 'Jharsuguda'),
          ZoneCity(id: 'city_in_19_16', name: 'Bargarh'),
          ZoneCity(id: 'city_in_19_17', name: 'Bolangir'),
          ZoneCity(id: 'city_in_19_18', name: 'Nuapada'),
          ZoneCity(id: 'city_in_19_19', name: 'Kalahandi'),
          ZoneCity(id: 'city_in_19_20', name: 'Nabarangapur'),
          ZoneCity(id: 'city_in_19_21', name: 'Koraput'),
          ZoneCity(id: 'city_in_19_22', name: 'Malkangiri'),
          ZoneCity(id: 'city_in_19_23', name: 'Rayagada'),
          ZoneCity(id: 'city_in_19_24', name: 'Gajapati'),
          ZoneCity(id: 'city_in_19_25', name: 'Kandhamal'),
          ZoneCity(id: 'city_in_19_26', name: 'Boudh'),
          ZoneCity(id: 'city_in_19_27', name: 'Sonepur'),
          ZoneCity(id: 'city_in_19_28', name: 'Boudh'),
          ZoneCity(id: 'city_in_19_29', name: 'Nayagarh'),
          ZoneCity(id: 'city_in_19_30', name: 'Khordha'),
          ZoneCity(id: 'city_in_19_31', name: 'Jagatsinghpur'),
        ],
      ),
      ZoneState(
        id: 'state_in_20',
        name: 'Punjab',
        cities: [
          ZoneCity(id: 'city_in_20_1', name: 'Amritsar'),
          ZoneCity(id: 'city_in_20_2', name: 'Ludhiana'),
          ZoneCity(id: 'city_in_20_3', name: 'Jalandhar'),
          ZoneCity(id: 'city_in_20_4', name: 'Patiala'),
          ZoneCity(id: 'city_in_20_5', name: 'Bathinda'),
          ZoneCity(id: 'city_in_20_6', name: 'Mohali'),
          ZoneCity(id: 'city_in_20_7', name: 'Firozpur'),
          ZoneCity(id: 'city_in_20_8', name: 'Gurdaspur'),
          ZoneCity(id: 'city_in_20_9', name: 'Hoshiarpur'),
          ZoneCity(id: 'city_in_20_10', name: 'Nawanshahr'),
          ZoneCity(id: 'city_in_20_11', name: 'Rupnagar'),
          ZoneCity(id: 'city_in_20_12', name: 'Fatehgarh Sahib'),
          ZoneCity(id: 'city_in_20_13', name: 'Sangrur'),
          ZoneCity(id: 'city_in_20_14', name: 'Barnala'),
          ZoneCity(id: 'city_in_20_15', name: 'Mansa'),
          ZoneCity(id: 'city_in_20_16', name: 'Muktsar'),
          ZoneCity(id: 'city_in_20_17', name: 'Fazilka'),
          ZoneCity(id: 'city_in_20_18', name: 'Faridkot'),
          ZoneCity(id: 'city_in_20_19', name: 'Moga'),
          ZoneCity(id: 'city_in_20_20', name: 'Kapurthala'),
          ZoneCity(id: 'city_in_20_21', name: 'Tarn Taran'),
          ZoneCity(id: 'city_in_20_22', name: 'Pathankot'),
          ZoneCity(id: 'city_in_20_23', name: 'Malerkotla'),
        ],
      ),
      ZoneState(
        id: 'state_in_21',
        name: 'Rajasthan',
        cities: [
          ZoneCity(id: 'city_in_21_1', name: 'Jaipur'),
          ZoneCity(id: 'city_in_21_2', name: 'Jodhpur'),
          ZoneCity(id: 'city_in_21_3', name: 'Udaipur'),
          ZoneCity(id: 'city_in_21_4', name: 'Kota'),
          ZoneCity(id: 'city_in_21_5', name: 'Ajmer'),
          ZoneCity(id: 'city_in_21_6', name: 'Bikaner'),
          ZoneCity(id: 'city_in_21_7', name: 'Alwar'),
          ZoneCity(id: 'city_in_21_8', name: 'Bharatpur'),
          ZoneCity(id: 'city_in_21_9', name: 'Sikar'),
          ZoneCity(id: 'city_in_21_10', name: 'Pali'),
          ZoneCity(id: 'city_in_21_11', name: 'Nagaur'),
          ZoneCity(id: 'city_in_21_12', name: 'Churu'),
          ZoneCity(id: 'city_in_21_13', name: 'Ganganagar'),
          ZoneCity(id: 'city_in_21_14', name: 'Hanumangarh'),
          ZoneCity(id: 'city_in_21_15', name: 'Jhunjhunu'),
          ZoneCity(id: 'city_in_21_16', name: 'Dungarpur'),
          ZoneCity(id: 'city_in_21_17', name: 'Banswara'),
          ZoneCity(id: 'city_in_21_18', name: 'Pratapgarh'),
          ZoneCity(id: 'city_in_21_19', name: 'Rajsamand'),
          ZoneCity(id: 'city_in_21_20', name: 'Chittorgarh'),
          ZoneCity(id: 'city_in_21_21', name: 'Bhilwara'),
          ZoneCity(id: 'city_in_21_22', name: 'Bundi'),
          ZoneCity(id: 'city_in_21_23', name: 'Tonk'),
          ZoneCity(id: 'city_in_21_24', name: 'Sawai Madhopur'),
          ZoneCity(id: 'city_in_21_25', name: 'Karauli'),
          ZoneCity(id: 'city_in_21_26', name: 'Dholpur'),
          ZoneCity(id: 'city_in_21_27', name: 'Dausa'),
          ZoneCity(id: 'city_in_21_28', name: 'Jaisalmer'),
          ZoneCity(id: 'city_in_21_29', name: 'Barmer'),
          ZoneCity(id: 'city_in_21_30', name: 'Jalore'),
          ZoneCity(id: 'city_in_21_31', name: 'Sirohi'),
          ZoneCity(id: 'city_in_21_32', name: 'Baran'),
          ZoneCity(id: 'city_in_21_33', name: 'Jhalawar'),
        ],
      ),
      ZoneState(
        id: 'state_in_22',
        name: 'Sikkim',
        cities: [
          ZoneCity(id: 'city_in_22_1', name: 'Gangtok'),
          ZoneCity(id: 'city_in_22_2', name: 'East Sikkim'),
          ZoneCity(id: 'city_in_22_3', name: 'West Sikkim'),
          ZoneCity(id: 'city_in_22_4', name: 'South Sikkim'),
          ZoneCity(id: 'city_in_22_5', name: 'North Sikkim'),
          ZoneCity(id: 'city_in_22_6', name: 'Pakyong'),
          ZoneCity(id: 'city_in_22_7', name: 'Soreng'),
        ],
      ),
      ZoneState(
        id: 'state_in_23',
        name: 'Tamil Nadu',
        cities: [
          ZoneCity(id: 'city_in_23_1', name: 'Chennai'),
          ZoneCity(id: 'city_in_23_2', name: 'Coimbatore'),
          ZoneCity(id: 'city_in_23_3', name: 'Madurai'),
          ZoneCity(id: 'city_in_23_4', name: 'Tiruchirappalli'),
          ZoneCity(id: 'city_in_23_5', name: 'Salem'),
          ZoneCity(id: 'city_in_23_6', name: 'Tirunelveli'),
          ZoneCity(id: 'city_in_23_7', name: 'Vellore'),
          ZoneCity(id: 'city_in_23_8', name: 'Erode'),
          ZoneCity(id: 'city_in_23_9', name: 'Tirupur'),
          ZoneCity(id: 'city_in_23_10', name: 'Thoothukudi'),
          ZoneCity(id: 'city_in_23_11', name: 'Kanniyakumari'),
          ZoneCity(id: 'city_in_23_12', name: 'Thanjavur'),
          ZoneCity(id: 'city_in_23_13', name: 'Dindigul'),
          ZoneCity(id: 'city_in_23_14', name: 'Cuddalore'),
          ZoneCity(id: 'city_in_23_15', name: 'Kancheepuram'),
          ZoneCity(id: 'city_in_23_16', name: 'Villupuram'),
          ZoneCity(id: 'city_in_23_17', name: 'Nagapattinam'),
          ZoneCity(id: 'city_in_23_18', name: 'Ariyalur'),
          ZoneCity(id: 'city_in_23_19', name: 'Perambalur'),
          ZoneCity(id: 'city_in_23_20', name: 'Tiruvarur'),
          ZoneCity(id: 'city_in_23_21', name: 'Pudukkottai'),
          ZoneCity(id: 'city_in_23_22', name: 'Sivaganga'),
          ZoneCity(id: 'city_in_23_23', name: 'Virudhunagar'),
          ZoneCity(id: 'city_in_23_24', name: 'Ramanathapuram'),
          ZoneCity(id: 'city_in_23_25', name: 'Theni'),
          ZoneCity(id: 'city_in_23_26', name: 'Krishnagiri'),
          ZoneCity(id: 'city_in_23_27', name: 'Dharmapuri'),
          ZoneCity(id: 'city_in_23_28', name: 'Namakkal'),
          ZoneCity(id: 'city_in_23_29', name: 'Nilgiris'),
          ZoneCity(id: 'city_in_23_30', name: 'Tiruvannamalai'),
          ZoneCity(id: 'city_in_23_31', name: 'Tenkasi'),
          ZoneCity(id: 'city_in_23_32', name: 'Chengalpattu'),
          ZoneCity(id: 'city_in_23_33', name: 'Ranipet'),
          ZoneCity(id: 'city_in_23_34', name: 'Tirupathur'),
          ZoneCity(id: 'city_in_23_35', name: 'Mayiladuthurai'),
          ZoneCity(id: 'city_in_23_36', name: 'Kallakurichi'),
          ZoneCity(id: 'city_in_23_37', name: 'Karur'),
        ],
      ),
      ZoneState(
        id: 'state_in_24',
        name: 'Telangana',
        cities: [
          ZoneCity(id: 'city_in_24_1', name: 'Hyderabad'),
          ZoneCity(id: 'city_in_24_2', name: 'Warangal'),
          ZoneCity(id: 'city_in_24_3', name: 'Nizamabad'),
          ZoneCity(id: 'city_in_24_4', name: 'Karimnagar'),
          ZoneCity(id: 'city_in_24_5', name: 'Khammam'),
          ZoneCity(id: 'city_in_24_6', name: 'Rangareddy'),
          ZoneCity(id: 'city_in_24_7', name: 'Mahbubnagar'),
          ZoneCity(id: 'city_in_24_8', name: 'Nalgonda'),
          ZoneCity(id: 'city_in_24_9', name: 'Adilabad'),
          ZoneCity(id: 'city_in_24_10', name: 'Medak'),
          ZoneCity(id: 'city_in_24_11', name: 'Rajanna Sircilla'),
          ZoneCity(id: 'city_in_24_12', name: 'Jayashankar'),
          ZoneCity(id: 'city_in_24_13', name: 'Peddapalli'),
          ZoneCity(id: 'city_in_24_14', name: 'Jagtial'),
          ZoneCity(id: 'city_in_24_15', name: 'Kamareddy'),
          ZoneCity(id: 'city_in_24_16', name: 'Sangareddy'),
          ZoneCity(id: 'city_in_24_17', name: 'Medchal-Malkajgiri'),
          ZoneCity(id: 'city_in_24_18', name: 'Vikarabad'),
          ZoneCity(id: 'city_in_24_19', name: 'Nagarkurnool'),
          ZoneCity(id: 'city_in_24_20', name: 'Suryapet'),
          ZoneCity(id: 'city_in_24_21', name: 'Yadadri'),
          ZoneCity(id: 'city_in_24_22', name: 'Bhupalpally'),
          ZoneCity(id: 'city_in_24_23', name: 'Mahabubabad'),
          ZoneCity(id: 'city_in_24_24', name: 'Bhadradri Kothagudem'),
          ZoneCity(id: 'city_in_24_25', name: 'Asifabad'),
          ZoneCity(id: 'city_in_24_26', name: 'Mancherial'),
          ZoneCity(id: 'city_in_24_27', name: 'Nirmal'),
          ZoneCity(id: 'city_in_24_28', name: 'Narayanpet'),
          ZoneCity(id: 'city_in_24_29', name: 'Wanaparthy'),
          ZoneCity(id: 'city_in_24_30', name: 'Jogulamba Gadwal'),
          ZoneCity(id: 'city_in_24_31', name: 'Nagar Kurnool'),
          ZoneCity(id: 'city_in_24_32', name: 'Mulugu'),
          ZoneCity(id: 'city_in_24_33', name: 'Narayanpet'),
        ],
      ),
      ZoneState(
        id: 'state_in_25',
        name: 'Tripura',
        cities: [
          ZoneCity(id: 'city_in_25_1', name: 'Agartala'),
          ZoneCity(id: 'city_in_25_2', name: 'West Tripura'),
          ZoneCity(id: 'city_in_25_3', name: 'Sepahijala'),
          ZoneCity(id: 'city_in_25_4', name: 'Gomati'),
          ZoneCity(id: 'city_in_25_5', name: 'South Tripura'),
          ZoneCity(id: 'city_in_25_6', name: 'Dhalai'),
          ZoneCity(id: 'city_in_25_7', name: 'Khowai'),
          ZoneCity(id: 'city_in_25_8', name: 'Unakoti'),
          ZoneCity(id: 'city_in_25_9', name: 'North Tripura'),
        ],
      ),
      ZoneState(
        id: 'state_in_26',
        name: 'Uttar Pradesh',
        cities: [
          ZoneCity(id: 'city_in_26_1', name: 'Lucknow'),
          ZoneCity(id: 'city_in_26_2', name: 'Agra'),
          ZoneCity(id: 'city_in_26_3', name: 'Varanasi'),
          ZoneCity(id: 'city_in_26_4', name: 'Prayagraj'),
          ZoneCity(id: 'city_in_26_5', name: 'Kanpur'),
          ZoneCity(id: 'city_in_26_6', name: 'Meerut'),
          ZoneCity(id: 'city_in_26_7', name: 'Ghaziabad'),
          ZoneCity(id: 'city_in_26_8', name: 'Noida'),
          ZoneCity(id: 'city_in_26_9', name: 'Mathura'),
          ZoneCity(id: 'city_in_26_10', name: 'Bareilly'),
          ZoneCity(id: 'city_in_26_11', name: 'Aligarh'),
          ZoneCity(id: 'city_in_26_12', name: 'Gorakhpur'),
          ZoneCity(id: 'city_in_26_13', name: 'Moradabad'),
          ZoneCity(id: 'city_in_26_14', name: 'Saharanpur'),
          ZoneCity(id: 'city_in_26_15', name: 'Firozabad'),
          ZoneCity(id: 'city_in_26_16', name: 'Jhansi'),
          ZoneCity(id: 'city_in_26_17', name: 'Muzaffarnagar'),
          ZoneCity(id: 'city_in_26_18', name: 'Bulandshahr'),
          ZoneCity(id: 'city_in_26_19', name: 'Shahjahanpur'),
          ZoneCity(id: 'city_in_26_20', name: 'Rampur'),
          ZoneCity(id: 'city_in_26_21', name: 'Hardoi'),
          ZoneCity(id: 'city_in_26_22', name: 'Lakhimpur Kheri'),
          ZoneCity(id: 'city_in_26_23', name: 'Sitapur'),
          ZoneCity(id: 'city_in_26_24', name: 'Unnao'),
          ZoneCity(id: 'city_in_26_25', name: 'Rae Bareli'),
          ZoneCity(id: 'city_in_26_26', name: 'Faizabad'),
          ZoneCity(id: 'city_in_26_27', name: 'Ambedkar Nagar'),
          ZoneCity(id: 'city_in_26_28', name: 'Sultanpur'),
          ZoneCity(id: 'city_in_26_29', name: 'Gonda'),
          ZoneCity(id: 'city_in_26_30', name: 'Basti'),
          ZoneCity(id: 'city_in_26_31', name: 'Siddharthnagar'),
          ZoneCity(id: 'city_in_26_32', name: 'Sant Kabir Nagar'),
          ZoneCity(id: 'city_in_26_33', name: 'Maharajganj'),
          ZoneCity(id: 'city_in_26_34', name: 'Deoria'),
          ZoneCity(id: 'city_in_26_35', name: 'Kushinagar'),
          ZoneCity(id: 'city_in_26_36', name: 'Ballia'),
          ZoneCity(id: 'city_in_26_37', name: 'Mau'),
          ZoneCity(id: 'city_in_26_38', name: 'Azamgarh'),
          ZoneCity(id: 'city_in_26_39', name: 'Jaunpur'),
          ZoneCity(id: 'city_in_26_40', name: 'Ghazipur'),
          ZoneCity(id: 'city_in_26_41', name: 'Mirzapur'),
          ZoneCity(id: 'city_in_26_42', name: 'Sonbhadra'),
          ZoneCity(id: 'city_in_26_43', name: 'Chandauli'),
          ZoneCity(id: 'city_in_26_44', name: 'Bhadohi'),
          ZoneCity(id: 'city_in_26_45', name: 'Pratapgarh'),
          ZoneCity(id: 'city_in_26_46', name: 'Kaushambi'),
          ZoneCity(id: 'city_in_26_47', name: 'Fatehpur'),
          ZoneCity(id: 'city_in_26_48', name: 'Banda'),
          ZoneCity(id: 'city_in_26_49', name: 'Chitrakoot'),
          ZoneCity(id: 'city_in_26_50', name: 'Hamirpur'),
          ZoneCity(id: 'city_in_26_51', name: 'Mahoba'),
          ZoneCity(id: 'city_in_26_52', name: 'Lalitpur'),
          ZoneCity(id: 'city_in_26_53', name: 'Etawah'),
          ZoneCity(id: 'city_in_26_54', name: 'Auraiya'),
          ZoneCity(id: 'city_in_26_55', name: 'Kanpur Dehat'),
          ZoneCity(id: 'city_in_26_56', name: 'Kannauj'),
          ZoneCity(id: 'city_in_26_57', name: 'Farrukhabad'),
          ZoneCity(id: 'city_in_26_58', name: 'Mainpuri'),
          ZoneCity(id: 'city_in_26_59', name: 'Etah'),
          ZoneCity(id: 'city_in_26_60', name: 'Hathras'),
          ZoneCity(id: 'city_in_26_61', name: 'Kasganj'),
          ZoneCity(id: 'city_in_26_62', name: 'Sambhal'),
          ZoneCity(id: 'city_in_26_63', name: 'Amroha'),
          ZoneCity(id: 'city_in_26_64', name: 'Hapur'),
          ZoneCity(id: 'city_in_26_65', name: 'Bagpat'),
          ZoneCity(id: 'city_in_26_66', name: 'Gautam Buddha Nagar'),
          ZoneCity(id: 'city_in_26_67', name: 'Balrampur'),
          ZoneCity(id: 'city_in_26_68', name: 'Shravasti'),
          ZoneCity(id: 'city_in_26_69', name: 'Bahraich'),
          ZoneCity(id: 'city_in_26_70', name: 'Pilibhit'),
          ZoneCity(id: 'city_in_26_71', name: 'Budaun'),
        ],
      ),
      ZoneState(
        id: 'state_in_27',
        name: 'Uttarakhand',
        cities: [
          ZoneCity(id: 'city_in_27_1', name: 'Dehradun'),
          ZoneCity(id: 'city_in_27_2', name: 'Haridwar'),
          ZoneCity(id: 'city_in_27_3', name: 'Roorkee'),
          ZoneCity(id: 'city_in_27_4', name: 'Nainital'),
          ZoneCity(id: 'city_in_27_5', name: 'Almora'),
          ZoneCity(id: 'city_in_27_6', name: 'Pithoragarh'),
          ZoneCity(id: 'city_in_27_7', name: 'Champawat'),
          ZoneCity(id: 'city_in_27_8', name: 'Bageshwar'),
          ZoneCity(id: 'city_in_27_9', name: 'Pauri Garhwal'),
          ZoneCity(id: 'city_in_27_10', name: 'Tehri Garhwal'),
          ZoneCity(id: 'city_in_27_11', name: 'Uttarkashi'),
          ZoneCity(id: 'city_in_27_12', name: 'Chamoli'),
          ZoneCity(id: 'city_in_27_13', name: 'Rudraprayag'),
          ZoneCity(id: 'city_in_27_14', name: 'Udham Singh Nagar'),
        ],
      ),
      ZoneState(
        id: 'state_in_28',
        name: 'West Bengal',
        cities: [
          ZoneCity(id: 'city_in_28_1', name: 'Kolkata'),
          ZoneCity(id: 'city_in_28_2', name: 'Haldia'),
          ZoneCity(id: 'city_in_28_3', name: 'Darjeeling'),
          ZoneCity(id: 'city_in_28_4', name: 'Siliguri'),
          ZoneCity(id: 'city_in_28_5', name: 'Howrah'),
          ZoneCity(id: 'city_in_28_6', name: 'Asansol'),
          ZoneCity(id: 'city_in_28_7', name: 'Durgapur'),
          ZoneCity(id: 'city_in_28_8', name: 'Kharagpur'),
          ZoneCity(id: 'city_in_28_9', name: 'Bardhaman'),
          ZoneCity(id: 'city_in_28_10', name: 'Bankura'),
          ZoneCity(id: 'city_in_28_11', name: 'Purulia'),
          ZoneCity(id: 'city_in_28_12', name: 'Jhargram'),
          ZoneCity(id: 'city_in_28_13', name: 'Birbhum'),
          ZoneCity(id: 'city_in_28_14', name: 'Murshidabad'),
          ZoneCity(id: 'city_in_28_15', name: 'Malda'),
          ZoneCity(id: 'city_in_28_16', name: 'North Dinajpur'),
          ZoneCity(id: 'city_in_28_17', name: 'South Dinajpur'),
          ZoneCity(id: 'city_in_28_18', name: 'Cooch Behar'),
          ZoneCity(id: 'city_in_28_19', name: 'Alipurduar'),
          ZoneCity(id: 'city_in_28_20', name: 'Jalpaiguri'),
          ZoneCity(id: 'city_in_28_21', name: 'Nadia'),
          ZoneCity(id: 'city_in_28_22', name: 'Hooghly'),
          ZoneCity(id: 'city_in_28_23', name: 'North 24 Parganas'),
          ZoneCity(id: 'city_in_28_24', name: 'South 24 Parganas'),
        ],
      ),
      ZoneState(
        id: 'state_in_29',
        name: 'Delhi',
        cities: [
          ZoneCity(id: 'city_in_29_1', name: 'New Delhi'),
          ZoneCity(id: 'city_in_29_2', name: 'Central Delhi'),
          ZoneCity(id: 'city_in_29_3', name: 'North Delhi'),
          ZoneCity(id: 'city_in_29_4', name: 'South Delhi'),
          ZoneCity(id: 'city_in_29_5', name: 'East Delhi'),
          ZoneCity(id: 'city_in_29_6', name: 'West Delhi'),
          ZoneCity(id: 'city_in_29_7', name: 'North West Delhi'),
          ZoneCity(id: 'city_in_29_8', name: 'South West Delhi'),
          ZoneCity(id: 'city_in_29_9', name: 'North East Delhi'),
          ZoneCity(id: 'city_in_29_10', name: 'Shahdara'),
          ZoneCity(id: 'city_in_29_11', name: 'Dwarka'),
        ],
      ),
      ZoneState(
        id: 'state_in_30',
        name: 'J&K',
        cities: [
          ZoneCity(id: 'city_in_30_1', name: 'Srinagar'),
          ZoneCity(id: 'city_in_30_2', name: 'Jammu'),
          ZoneCity(id: 'city_in_30_3', name: 'Anantnag'),
          ZoneCity(id: 'city_in_30_4', name: 'Baramulla'),
          ZoneCity(id: 'city_in_30_5', name: 'Budgam'),
          ZoneCity(id: 'city_in_30_6', name: 'Bandipora'),
          ZoneCity(id: 'city_in_30_7', name: 'Ganderbal'),
          ZoneCity(id: 'city_in_30_8', name: 'Kupwara'),
          ZoneCity(id: 'city_in_30_9', name: 'Pulwama'),
          ZoneCity(id: 'city_in_30_10', name: 'Shopian'),
          ZoneCity(id: 'city_in_30_11', name: 'Kulgam'),
          ZoneCity(id: 'city_in_30_12', name: 'Reasi'),
          ZoneCity(id: 'city_in_30_13', name: 'Rajouri'),
          ZoneCity(id: 'city_in_30_14', name: 'Poonch'),
          ZoneCity(id: 'city_in_30_15', name: 'Ramban'),
          ZoneCity(id: 'city_in_30_16', name: 'Doda'),
          ZoneCity(id: 'city_in_30_17', name: 'Kishtwar'),
          ZoneCity(id: 'city_in_30_18', name: 'Kathua'),
          ZoneCity(id: 'city_in_30_19', name: 'Samba'),
          ZoneCity(id: 'city_in_30_20', name: 'Udhampur'),
        ],
      ),
      ZoneState(
        id: 'state_in_31',
        name: 'Ladakh',
        cities: [
          ZoneCity(id: 'city_in_31_1', name: 'Leh'),
          ZoneCity(id: 'city_in_31_2', name: 'Kargil'),
        ],
      ),
      ZoneState(
        id: 'state_in_32',
        name: 'Puducherry',
        cities: [
          ZoneCity(id: 'city_in_32_1', name: 'Puducherry'),
        ],
      ),
      ZoneState(
        id: 'state_in_33',
        name: 'Dadra & NH',
        cities: [
          ZoneCity(id: 'city_in_33_1', name: 'Silvassa'),
          ZoneCity(id: 'city_in_33_2', name: 'Dadra'),
        ],
      ),
      ZoneState(
        id: 'state_in_34',
        name: 'Daman & Diu',
        cities: [
          ZoneCity(id: 'city_in_34_1', name: 'Daman'),
          ZoneCity(id: 'city_in_34_2', name: 'Diu'),
        ],
      ),
      ZoneState(
        id: 'state_in_35',
        name: 'Lakshadweep',
        cities: [
          ZoneCity(id: 'city_in_35_1', name: 'Kavaratti'),
        ],
      ),
      ZoneState(
        id: 'state_in_36',
        name: 'Andaman & Nicobar',
        cities: [
          ZoneCity(id: 'city_in_36_1', name: 'Port Blair'),
        ],
      ),
    ],
  ),
];

// --- Helper ---
List<String> getCityNamesFromIds(List<dynamic> cityIds) {
  final Map<String, ZoneCity> cityMap = {};
  for (var country in mockDeliveryData) {
    for (var state in country.states) {
      for (var city in state.cities) {
        cityMap[city.id] = city;
      }
    }
  }
  return cityIds.map((id) => cityMap[id.toString()]?.name ?? id.toString()).toList();
}

// --- Component ---
class DeliveryZoneSelector extends StatefulWidget {
  final List<ZoneCountry> data;
  final ValueChanged<List<String>> onSelectionChanged;
  final List<String>? initialSelection;

  const DeliveryZoneSelector({
    super.key,
    required this.data,
    required this.onSelectionChanged,
    this.initialSelection,
  });

  @override
  State<DeliveryZoneSelector> createState() => _DeliveryZoneSelectorState();
}

class _DeliveryZoneSelectorState extends State<DeliveryZoneSelector> {
  String? _selectedCountryId;

  // States actively checked by the user (determines visibility of city list)
  final Set<String> _checkedStateIds = {};

  // Cities actively selected by the user (determines final payload)
  final Set<String> _selectedCityIds = {};

  // Lookup maps for easy data retrieval and summary rendering
  final Map<String, ZoneCity> _cityMap = {};
  final Map<String, ZoneState> _stateMap = {};

  @override
  void initState() {
    super.initState();
    _buildLookupMaps();
    _initializeSelection();
  }

  void _initializeSelection() {
    if (widget.initialSelection != null && widget.initialSelection!.isNotEmpty) {
      _selectedCityIds.addAll(widget.initialSelection!);
      
      // Auto-expand states that contain any of the initially selected cities
      for (var stateId in _stateMap.keys) {
        final state = _stateMap[stateId]!;
        final stateCityIds = state.cities.map((c) => c.id).toSet();
        if (stateCityIds.intersection(_selectedCityIds).isNotEmpty) {
          _checkedStateIds.add(stateId);
          // Also set the country to the first one we find that has a selected state
          if (_selectedCountryId == null) {
            _selectedCountryId = widget.data.firstWhere((c) => c.states.any((s) => s.id == stateId)).id;
          }
        }
      }
    }
  }

  void _buildLookupMaps() {
    for (var country in widget.data) {
      for (var state in country.states) {
        _stateMap[state.id] = state;
        for (var city in state.cities) {
          _cityMap[city.id] = city;
        }
      }
    }
  }

  void _notifyChange() {
    widget.onSelectionChanged(_selectedCityIds.toList());
  }

  // --- Actions ---

  void _onCountryChanged(String? countryId) {
    setState(() {
      _selectedCountryId = countryId;
      // We don't clear the selected cities when switching countries.
      // This allows the supplier to select zones across multiple countries if desired.
    });
  }

  void _toggleState(String stateId, bool? value) {
    final isChecked = value ?? false;
    setState(() {
      if (isChecked) {
        _checkedStateIds.add(stateId);
      } else {
        _checkedStateIds.remove(stateId);
        // Cascading Deselection: Remove all cities belonging to this state
        final state = _stateMap[stateId];
        if (state != null) {
          final cityIds = state.cities.map((c) => c.id);
          _selectedCityIds.removeAll(cityIds);
        }
      }
    });
    _notifyChange();
  }

  void _toggleSelectAllStates(bool? value) {
    final isChecked = value ?? false;
    final currentCountry = widget.data.firstWhere((c) => c.id == _selectedCountryId);

    setState(() {
      if (isChecked) {
        // Select all states and ALL underlying cities in the backend
        for (var state in currentCountry.states) {
          _checkedStateIds.add(state.id);
          _selectedCityIds.addAll(state.cities.map((c) => c.id));
        }
      } else {
        // Deselect all states and remove all underlying cities
        for (var state in currentCountry.states) {
          _checkedStateIds.remove(state.id);
          _selectedCityIds.removeAll(state.cities.map((c) => c.id));
        }
      }
    });
    _notifyChange();
  }

  void _toggleCity(String cityId, bool? value) {
    final isChecked = value ?? false;
    setState(() {
      if (isChecked) {
        _selectedCityIds.add(cityId);
      } else {
        _selectedCityIds.remove(cityId);
      }
    });
    _notifyChange();
  }

  void _toggleAllCitiesForState(String stateId, bool? value) {
    final isChecked = value ?? false;
    final state = _stateMap[stateId];
    if (state == null) return;

    setState(() {
      if (isChecked) {
        _selectedCityIds.addAll(state.cities.map((c) => c.id));
      } else {
        _selectedCityIds.removeAll(state.cities.map((c) => c.id));
      }
    });
    _notifyChange();
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Zone Selector',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the regions where you can deliver products. The final configuration will be saved in your profile.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Tier 1: Country Selection
          _buildCountryDropdown(theme),
          const SizedBox(height: 24),

          // Tiers 2 & 3: Cascading Area
          if (_selectedCountryId != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive layout: Row for wide screens, Column for narrow
                if (constraints.maxWidth > 600) {
                  return SizedBox(
                    height: 400,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildStateList(theme, accentColor)),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _buildCityList(theme, accentColor)),
                      ],
                    ),
                  );
                } else {
                  return Column(
                    children: [
                      SizedBox(height: 300, child: _buildStateList(theme, accentColor)),
                      const SizedBox(height: 24),
                      SizedBox(height: 300, child: _buildCityList(theme, accentColor)),
                    ],
                  );
                }
              },
            ),
          ],
          
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 24),

          // Summary Panel
          _buildSummaryPanel(theme),
        ],
      ),
    );
  }

  Widget _buildCountryDropdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tier 1: Country Selection', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: theme.colorScheme.surface,
              hint: Text('Select a country', style: theme.textTheme.bodyMedium),
              value: _selectedCountryId,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              items: widget.data.map((country) {
                return DropdownMenuItem(
                  value: country.id,
                  child: Text(country.name, style: theme.textTheme.bodyLarge),
                );
              }).toList(),
              onChanged: _onCountryChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateList(ThemeData theme, Color accentColor) {
    final currentCountry = widget.data.firstWhere((c) => c.id == _selectedCountryId);
    final allStatesChecked = currentCountry.states.isNotEmpty &&
        currentCountry.states.every((s) => _checkedStateIds.contains(s.id));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tier 2: States', style: theme.textTheme.titleMedium),
                Row(
                  children: [
                    Text('Select All', style: theme.textTheme.bodySmall),
                    Switch(
                      value: allStatesChecked,
                      onChanged: _toggleSelectAllStates,
                      activeColor: accentColor,
                    ),
                  ],
                )
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView.builder(
              itemCount: currentCountry.states.length,
              itemBuilder: (context, index) {
                final state = currentCountry.states[index];
                final isChecked = _checkedStateIds.contains(state.id);
                return CheckboxListTile(
                  title: Text(state.name, style: theme.textTheme.bodyLarge),
                  subtitle: Text('${state.cities.length} cities', style: theme.textTheme.bodySmall),
                  value: isChecked,
                  activeColor: accentColor,
                  checkColor: theme.scaffoldBackgroundColor,
                  onChanged: (val) => _toggleState(state.id, val),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityList(ThemeData theme, Color accentColor) {
    final currentCountry = widget.data.firstWhere((c) => c.id == _selectedCountryId);
    final visibleStates = currentCountry.states.where((s) => _checkedStateIds.contains(s.id)).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Tier 3: Cities', style: theme.textTheme.titleMedium),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: visibleStates.isEmpty
                ? Center(
                    child: Text(
                      'Check a state to view cities',
                      style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  )
                : ListView.builder(
                    itemCount: visibleStates.length,
                    itemBuilder: (context, stateIndex) {
                      final state = visibleStates[stateIndex];
                      final allCitiesInStateSelected = state.cities.every((c) => _selectedCityIds.contains(c.id));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: Colors.white.withOpacity(0.03),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  state.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: [
                                    Text('All in ${state.name}', style: theme.textTheme.bodySmall),
                                    Switch(
                                      value: allCitiesInStateSelected,
                                      onChanged: (val) => _toggleAllCitiesForState(state.id, val),
                                      activeColor: accentColor,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ...state.cities.map((city) {
                            return CheckboxListTile(
                              title: Text(city.name, style: theme.textTheme.bodyLarge),
                              value: _selectedCityIds.contains(city.id),
                              activeColor: accentColor,
                              checkColor: theme.scaffoldBackgroundColor,
                              onChanged: (val) => _toggleCity(city.id, val),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.only(left: 32, right: 16), // Indent under state
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel(ThemeData theme) {
    final selectedCityNames = _selectedCityIds.map((id) => _cityMap[id]?.name ?? id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text('Delivery Coverage Summary', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              '${_selectedCityIds.length} Zones Selected',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedCityIds.isEmpty)
          Text('No delivery zones selected yet.', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedCityNames.map((name) {
              return Chip(
                label: Text(name, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.surface)),
                backgroundColor: theme.colorScheme.primary,
                deleteIconColor: theme.colorScheme.surface,
                onDeleted: () {
                  // Find the ID for this name to delete it
                  final idToRemove = _cityMap.keys.firstWhere(
                    (k) => _cityMap[k]?.name == name,
                    orElse: () => '',
                  );
                  if (idToRemove.isNotEmpty) {
                    _toggleCity(idToRemove, false);
                  }
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}
