import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Data Models ---
class ZoneCity {
  final String id;
  final String name;
  const ZoneCity({required this.id, required this.name});
}

class ZoneState {
  final String id;
  final String name;
  final List<ZoneCity> cities;
  const ZoneState({required this.id, required this.name, required this.cities});
}

class ZoneCountry {
  final String id;
  final String name;
  final List<ZoneState> states;
  const ZoneCountry({required this.id, required this.name, required this.states});
}

// --- Mock Data ---
const List<ZoneCountry> mockDeliveryData = [
  ZoneCountry(
    id: 'country_in',
    name: 'India',
    states: [
      ZoneState(
        id: 'state_in_1',
        name: 'Andaman & Nicobar',
        cities: [
          ZoneCity(id: 'city_in_1_1', name: 'Port Blair'),
        ],
      ),
      ZoneState(
        id: 'state_in_2',
        name: 'Andhra Pradesh',
        cities: [
          ZoneCity(id: 'city_in_2_1', name: 'Alluri Sitharama Raju'),
          ZoneCity(id: 'city_in_2_2', name: 'Anakapalli'),
          ZoneCity(id: 'city_in_2_3', name: 'Anantapur'),
          ZoneCity(id: 'city_in_2_4', name: 'Bapatla'),
          ZoneCity(id: 'city_in_2_5', name: 'Chittoor'),
          ZoneCity(id: 'city_in_2_6', name: 'East Godavari'),
          ZoneCity(id: 'city_in_2_7', name: 'Eluru'),
          ZoneCity(id: 'city_in_2_8', name: 'Guntur'),
          ZoneCity(id: 'city_in_2_9', name: 'Kadapa'),
          ZoneCity(id: 'city_in_2_10', name: 'Konaseema'),
          ZoneCity(id: 'city_in_2_11', name: 'Kurnool'),
          ZoneCity(id: 'city_in_2_12', name: 'NTR District'),
          ZoneCity(id: 'city_in_2_13', name: 'Nellore'),
          ZoneCity(id: 'city_in_2_14', name: 'Parvathipuram Manyam'),
          ZoneCity(id: 'city_in_2_15', name: 'Prakasam'),
          ZoneCity(id: 'city_in_2_16', name: 'Sri Potti Sriramulu Nellore'),
          ZoneCity(id: 'city_in_2_17', name: 'Sri Sathya Sai'),
          ZoneCity(id: 'city_in_2_18', name: 'Srikakulam'),
          ZoneCity(id: 'city_in_2_19', name: 'Tirupati'),
          ZoneCity(id: 'city_in_2_20', name: 'Vijayawada'),
          ZoneCity(id: 'city_in_2_21', name: 'Visakhapatnam'),
          ZoneCity(id: 'city_in_2_22', name: 'Vizianagaram'),
          ZoneCity(id: 'city_in_2_23', name: 'West Godavari'),
        ],
      ),
      ZoneState(
        id: 'state_in_3',
        name: 'Arunachal Pradesh',
        cities: [
          ZoneCity(id: 'city_in_3_1', name: 'Anjaw'),
          ZoneCity(id: 'city_in_3_2', name: 'Changlang'),
          ZoneCity(id: 'city_in_3_3', name: 'Dibang Valley'),
          ZoneCity(id: 'city_in_3_4', name: 'East Kameng'),
          ZoneCity(id: 'city_in_3_5', name: 'East Siang'),
          ZoneCity(id: 'city_in_3_6', name: 'Itanagar'),
          ZoneCity(id: 'city_in_3_7', name: 'Kamle'),
          ZoneCity(id: 'city_in_3_8', name: 'Kra Daadi'),
          ZoneCity(id: 'city_in_3_9', name: 'Kurung Kumey'),
          ZoneCity(id: 'city_in_3_10', name: 'Lepa Rada'),
          ZoneCity(id: 'city_in_3_11', name: 'Lohit'),
          ZoneCity(id: 'city_in_3_12', name: 'Longding'),
          ZoneCity(id: 'city_in_3_13', name: 'Lower Dibang Valley'),
          ZoneCity(id: 'city_in_3_14', name: 'Lower Subansiri'),
          ZoneCity(id: 'city_in_3_15', name: 'Namsai'),
          ZoneCity(id: 'city_in_3_16', name: 'Pakke Kessang'),
          ZoneCity(id: 'city_in_3_17', name: 'Papum Pare'),
          ZoneCity(id: 'city_in_3_18', name: 'Shi Yomi'),
          ZoneCity(id: 'city_in_3_19', name: 'Siang'),
          ZoneCity(id: 'city_in_3_20', name: 'Tawang'),
          ZoneCity(id: 'city_in_3_21', name: 'Tirap'),
          ZoneCity(id: 'city_in_3_22', name: 'Upper Siang'),
          ZoneCity(id: 'city_in_3_23', name: 'Upper Subansiri'),
          ZoneCity(id: 'city_in_3_24', name: 'West Kameng'),
          ZoneCity(id: 'city_in_3_25', name: 'West Siang'),
        ],
      ),
      ZoneState(
        id: 'state_in_4',
        name: 'Assam',
        cities: [
          ZoneCity(id: 'city_in_4_1', name: 'Bajali'),
          ZoneCity(id: 'city_in_4_2', name: 'Baksa'),
          ZoneCity(id: 'city_in_4_3', name: 'Barpeta'),
          ZoneCity(id: 'city_in_4_4', name: 'Biswanath'),
          ZoneCity(id: 'city_in_4_5', name: 'Bongaigaon'),
          ZoneCity(id: 'city_in_4_6', name: 'Cachar'),
          ZoneCity(id: 'city_in_4_7', name: 'Charaideo'),
          ZoneCity(id: 'city_in_4_8', name: 'Chirang'),
          ZoneCity(id: 'city_in_4_9', name: 'Darrang'),
          ZoneCity(id: 'city_in_4_10', name: 'Dhemaji'),
          ZoneCity(id: 'city_in_4_11', name: 'Dhubri'),
          ZoneCity(id: 'city_in_4_12', name: 'Dibrugarh'),
          ZoneCity(id: 'city_in_4_13', name: 'Dima Hasao'),
          ZoneCity(id: 'city_in_4_14', name: 'East Karbi Anglong'),
          ZoneCity(id: 'city_in_4_15', name: 'Goalpara'),
          ZoneCity(id: 'city_in_4_16', name: 'Golaghat'),
          ZoneCity(id: 'city_in_4_17', name: 'Guwahati'),
          ZoneCity(id: 'city_in_4_18', name: 'Hailakandi'),
          ZoneCity(id: 'city_in_4_19', name: 'Hojai'),
          ZoneCity(id: 'city_in_4_20', name: 'Jorhat'),
          ZoneCity(id: 'city_in_4_21', name: 'Kamrup'),
          ZoneCity(id: 'city_in_4_22', name: 'Karbi Anglong'),
          ZoneCity(id: 'city_in_4_23', name: 'Karimganj'),
          ZoneCity(id: 'city_in_4_24', name: 'Kokrajhar'),
          ZoneCity(id: 'city_in_4_25', name: 'Lakhimpur'),
          ZoneCity(id: 'city_in_4_26', name: 'Majuli'),
          ZoneCity(id: 'city_in_4_27', name: 'Morigaon'),
          ZoneCity(id: 'city_in_4_28', name: 'Nagaon'),
          ZoneCity(id: 'city_in_4_29', name: 'Nalbari'),
          ZoneCity(id: 'city_in_4_30', name: 'Sibsagar'),
          ZoneCity(id: 'city_in_4_31', name: 'Sonitpur'),
          ZoneCity(id: 'city_in_4_32', name: 'South Salmara'),
          ZoneCity(id: 'city_in_4_33', name: 'Tamulpur'),
          ZoneCity(id: 'city_in_4_34', name: 'Tinsukia'),
          ZoneCity(id: 'city_in_4_35', name: 'Udalguri'),
          ZoneCity(id: 'city_in_4_36', name: 'West Karbi Anglong'),
        ],
      ),
      ZoneState(
        id: 'state_in_5',
        name: 'Bihar',
        cities: [
          ZoneCity(id: 'city_in_5_1', name: 'Araria'),
          ZoneCity(id: 'city_in_5_2', name: 'Arwal'),
          ZoneCity(id: 'city_in_5_3', name: 'Aurangabad'),
          ZoneCity(id: 'city_in_5_4', name: 'Banka'),
          ZoneCity(id: 'city_in_5_5', name: 'Begusarai'),
          ZoneCity(id: 'city_in_5_6', name: 'Bhagalpur'),
          ZoneCity(id: 'city_in_5_7', name: 'Bhojpur'),
          ZoneCity(id: 'city_in_5_8', name: 'Buxar'),
          ZoneCity(id: 'city_in_5_9', name: 'Darbhanga'),
          ZoneCity(id: 'city_in_5_10', name: 'East Champaran'),
          ZoneCity(id: 'city_in_5_11', name: 'Gaya'),
          ZoneCity(id: 'city_in_5_12', name: 'Gopalganj'),
          ZoneCity(id: 'city_in_5_13', name: 'Jamui'),
          ZoneCity(id: 'city_in_5_14', name: 'Jehanabad'),
          ZoneCity(id: 'city_in_5_15', name: 'Kaimur'),
          ZoneCity(id: 'city_in_5_16', name: 'Katihar'),
          ZoneCity(id: 'city_in_5_17', name: 'Khagaria'),
          ZoneCity(id: 'city_in_5_18', name: 'Kishanganj'),
          ZoneCity(id: 'city_in_5_19', name: 'Lakhisarai'),
          ZoneCity(id: 'city_in_5_20', name: 'Madhepura'),
          ZoneCity(id: 'city_in_5_21', name: 'Madhubani'),
          ZoneCity(id: 'city_in_5_22', name: 'Munger'),
          ZoneCity(id: 'city_in_5_23', name: 'Muzaffarpur'),
          ZoneCity(id: 'city_in_5_24', name: 'Nalanda'),
          ZoneCity(id: 'city_in_5_25', name: 'Nawada'),
          ZoneCity(id: 'city_in_5_26', name: 'Patna'),
          ZoneCity(id: 'city_in_5_27', name: 'Purnia'),
          ZoneCity(id: 'city_in_5_28', name: 'Rohtas'),
          ZoneCity(id: 'city_in_5_29', name: 'Saharsa'),
          ZoneCity(id: 'city_in_5_30', name: 'Samastipur'),
          ZoneCity(id: 'city_in_5_31', name: 'Saran'),
          ZoneCity(id: 'city_in_5_32', name: 'Sheikhpura'),
          ZoneCity(id: 'city_in_5_33', name: 'Sheohar'),
          ZoneCity(id: 'city_in_5_34', name: 'Sitamarhi'),
          ZoneCity(id: 'city_in_5_35', name: 'Siwan'),
          ZoneCity(id: 'city_in_5_36', name: 'Supaul'),
          ZoneCity(id: 'city_in_5_37', name: 'Vaishali'),
          ZoneCity(id: 'city_in_5_38', name: 'West Champaran'),
        ],
      ),
      ZoneState(
        id: 'state_in_6',
        name: 'Chhattisgarh',
        cities: [
          ZoneCity(id: 'city_in_6_1', name: 'Balod'),
          ZoneCity(id: 'city_in_6_2', name: 'Baloda Bazar'),
          ZoneCity(id: 'city_in_6_3', name: 'Balrampur'),
          ZoneCity(id: 'city_in_6_4', name: 'Bastar'),
          ZoneCity(id: 'city_in_6_5', name: 'Bemetara'),
          ZoneCity(id: 'city_in_6_6', name: 'Bijapur'),
          ZoneCity(id: 'city_in_6_7', name: 'Bilaspur'),
          ZoneCity(id: 'city_in_6_8', name: 'Dantewada'),
          ZoneCity(id: 'city_in_6_9', name: 'Durg'),
          ZoneCity(id: 'city_in_6_10', name: 'Gariaband'),
          ZoneCity(id: 'city_in_6_11', name: 'Gaurela-Pendra'),
          ZoneCity(id: 'city_in_6_12', name: 'Janjgir-Champa'),
          ZoneCity(id: 'city_in_6_13', name: 'Jashpur'),
          ZoneCity(id: 'city_in_6_14', name: 'Kanker'),
          ZoneCity(id: 'city_in_6_15', name: 'Kawardha'),
          ZoneCity(id: 'city_in_6_16', name: 'Khairagarh'),
          ZoneCity(id: 'city_in_6_17', name: 'Kondagaon'),
          ZoneCity(id: 'city_in_6_18', name: 'Korba'),
          ZoneCity(id: 'city_in_6_19', name: 'Koriya'),
          ZoneCity(id: 'city_in_6_20', name: 'Mahasamund'),
          ZoneCity(id: 'city_in_6_21', name: 'Manendragarh'),
          ZoneCity(id: 'city_in_6_22', name: 'Mohla-Manpur'),
          ZoneCity(id: 'city_in_6_23', name: 'Mungeli'),
          ZoneCity(id: 'city_in_6_24', name: 'Narayanpur'),
          ZoneCity(id: 'city_in_6_25', name: 'Raigarh'),
          ZoneCity(id: 'city_in_6_26', name: 'Raipur'),
          ZoneCity(id: 'city_in_6_27', name: 'Rajnandgaon'),
          ZoneCity(id: 'city_in_6_28', name: 'Sakti'),
          ZoneCity(id: 'city_in_6_29', name: 'Sarangarh-Bilaigarh'),
          ZoneCity(id: 'city_in_6_30', name: 'Shakti'),
          ZoneCity(id: 'city_in_6_31', name: 'Sukma'),
          ZoneCity(id: 'city_in_6_32', name: 'Surajpur'),
          ZoneCity(id: 'city_in_6_33', name: 'Surguja'),
        ],
      ),
      ZoneState(
        id: 'state_in_7',
        name: 'Dadra & NH',
        cities: [
          ZoneCity(id: 'city_in_7_1', name: 'Dadra'),
          ZoneCity(id: 'city_in_7_2', name: 'Silvassa'),
        ],
      ),
      ZoneState(
        id: 'state_in_8',
        name: 'Daman & Diu',
        cities: [
          ZoneCity(id: 'city_in_8_1', name: 'Daman'),
          ZoneCity(id: 'city_in_8_2', name: 'Diu'),
        ],
      ),
      ZoneState(
        id: 'state_in_9',
        name: 'Delhi',
        cities: [
          ZoneCity(id: 'city_in_9_1', name: 'Central Delhi'),
          ZoneCity(id: 'city_in_9_2', name: 'Dwarka'),
          ZoneCity(id: 'city_in_9_3', name: 'East Delhi'),
          ZoneCity(id: 'city_in_9_4', name: 'New Delhi'),
          ZoneCity(id: 'city_in_9_5', name: 'North Delhi'),
          ZoneCity(id: 'city_in_9_6', name: 'North East Delhi'),
          ZoneCity(id: 'city_in_9_7', name: 'North West Delhi'),
          ZoneCity(id: 'city_in_9_8', name: 'Shahdara'),
          ZoneCity(id: 'city_in_9_9', name: 'South Delhi'),
          ZoneCity(id: 'city_in_9_10', name: 'South West Delhi'),
          ZoneCity(id: 'city_in_9_11', name: 'West Delhi'),
        ],
      ),
      ZoneState(
        id: 'state_in_10',
        name: 'Goa',
        cities: [
          ZoneCity(id: 'city_in_10_1', name: 'Margao'),
          ZoneCity(id: 'city_in_10_2', name: 'Panaji'),
        ],
      ),
      ZoneState(
        id: 'state_in_11',
        name: 'Gujarat',
        cities: [
          ZoneCity(id: 'city_in_11_1', name: 'Ahmedabad'),
          ZoneCity(id: 'city_in_11_2', name: 'Amreli'),
          ZoneCity(id: 'city_in_11_3', name: 'Anand'),
          ZoneCity(id: 'city_in_11_4', name: 'Aravalli'),
          ZoneCity(id: 'city_in_11_5', name: 'Banaskantha'),
          ZoneCity(id: 'city_in_11_6', name: 'Bharuch'),
          ZoneCity(id: 'city_in_11_7', name: 'Bhavnagar'),
          ZoneCity(id: 'city_in_11_8', name: 'Botad'),
          ZoneCity(id: 'city_in_11_9', name: 'Chhota Udaipur'),
          ZoneCity(id: 'city_in_11_10', name: 'Dahod'),
          ZoneCity(id: 'city_in_11_11', name: 'Dang'),
          ZoneCity(id: 'city_in_11_12', name: 'Dwarka'),
          ZoneCity(id: 'city_in_11_13', name: 'Gandhinagar'),
          ZoneCity(id: 'city_in_11_14', name: 'Gir Somnath'),
          ZoneCity(id: 'city_in_11_15', name: 'Jamnagar'),
          ZoneCity(id: 'city_in_11_16', name: 'Junagadh'),
          ZoneCity(id: 'city_in_11_17', name: 'Kandla'),
          ZoneCity(id: 'city_in_11_18', name: 'Kheda'),
          ZoneCity(id: 'city_in_11_19', name: 'Kutch'),
          ZoneCity(id: 'city_in_11_20', name: 'Mahisagar'),
          ZoneCity(id: 'city_in_11_21', name: 'Mehsana'),
          ZoneCity(id: 'city_in_11_22', name: 'Morbi'),
          ZoneCity(id: 'city_in_11_23', name: 'Mundra'),
          ZoneCity(id: 'city_in_11_24', name: 'Narmada'),
          ZoneCity(id: 'city_in_11_25', name: 'Navsari'),
          ZoneCity(id: 'city_in_11_26', name: 'Panchmahal'),
          ZoneCity(id: 'city_in_11_27', name: 'Patan'),
          ZoneCity(id: 'city_in_11_28', name: 'Porbandar'),
          ZoneCity(id: 'city_in_11_29', name: 'Rajkot'),
          ZoneCity(id: 'city_in_11_30', name: 'Sabarkantha'),
          ZoneCity(id: 'city_in_11_31', name: 'Surat'),
          ZoneCity(id: 'city_in_11_32', name: 'Tapi'),
          ZoneCity(id: 'city_in_11_33', name: 'Vadodara'),
          ZoneCity(id: 'city_in_11_34', name: 'Valsad'),
        ],
      ),
      ZoneState(
        id: 'state_in_12',
        name: 'Haryana',
        cities: [
          ZoneCity(id: 'city_in_12_1', name: 'Ambala'),
          ZoneCity(id: 'city_in_12_2', name: 'Bhiwani'),
          ZoneCity(id: 'city_in_12_3', name: 'Chandigarh'),
          ZoneCity(id: 'city_in_12_4', name: 'Charkhi Dadri'),
          ZoneCity(id: 'city_in_12_5', name: 'Faridabad'),
          ZoneCity(id: 'city_in_12_6', name: 'Fatehabad'),
          ZoneCity(id: 'city_in_12_7', name: 'Gurugram'),
          ZoneCity(id: 'city_in_12_8', name: 'Hisar'),
          ZoneCity(id: 'city_in_12_9', name: 'Jhajjar'),
          ZoneCity(id: 'city_in_12_10', name: 'Jind'),
          ZoneCity(id: 'city_in_12_11', name: 'Kaithal'),
          ZoneCity(id: 'city_in_12_12', name: 'Karnal'),
          ZoneCity(id: 'city_in_12_13', name: 'Kurukshetra'),
          ZoneCity(id: 'city_in_12_14', name: 'Mahendragarh'),
          ZoneCity(id: 'city_in_12_15', name: 'Nuh'),
          ZoneCity(id: 'city_in_12_16', name: 'Palwal'),
          ZoneCity(id: 'city_in_12_17', name: 'Panchkula'),
          ZoneCity(id: 'city_in_12_18', name: 'Panipat'),
          ZoneCity(id: 'city_in_12_19', name: 'Rewari'),
          ZoneCity(id: 'city_in_12_20', name: 'Rohtak'),
          ZoneCity(id: 'city_in_12_21', name: 'Sirsa'),
          ZoneCity(id: 'city_in_12_22', name: 'Sonipat'),
          ZoneCity(id: 'city_in_12_23', name: 'Yamunanagar'),
        ],
      ),
      ZoneState(
        id: 'state_in_13',
        name: 'Himachal Pradesh',
        cities: [
          ZoneCity(id: 'city_in_13_1', name: 'Bilaspur'),
          ZoneCity(id: 'city_in_13_2', name: 'Chamba'),
          ZoneCity(id: 'city_in_13_3', name: 'Hamirpur'),
          ZoneCity(id: 'city_in_13_4', name: 'Kangra'),
          ZoneCity(id: 'city_in_13_5', name: 'Kinnaur'),
          ZoneCity(id: 'city_in_13_6', name: 'Kullu'),
          ZoneCity(id: 'city_in_13_7', name: 'Lahaul Spiti'),
          ZoneCity(id: 'city_in_13_8', name: 'Mandi'),
          ZoneCity(id: 'city_in_13_9', name: 'Shimla'),
          ZoneCity(id: 'city_in_13_10', name: 'Sirmaur'),
          ZoneCity(id: 'city_in_13_11', name: 'Solan'),
          ZoneCity(id: 'city_in_13_12', name: 'Una'),
        ],
      ),
      ZoneState(
        id: 'state_in_14',
        name: 'J&K',
        cities: [
          ZoneCity(id: 'city_in_14_1', name: 'Anantnag'),
          ZoneCity(id: 'city_in_14_2', name: 'Bandipora'),
          ZoneCity(id: 'city_in_14_3', name: 'Baramulla'),
          ZoneCity(id: 'city_in_14_4', name: 'Budgam'),
          ZoneCity(id: 'city_in_14_5', name: 'Doda'),
          ZoneCity(id: 'city_in_14_6', name: 'Ganderbal'),
          ZoneCity(id: 'city_in_14_7', name: 'Jammu'),
          ZoneCity(id: 'city_in_14_8', name: 'Kathua'),
          ZoneCity(id: 'city_in_14_9', name: 'Kishtwar'),
          ZoneCity(id: 'city_in_14_10', name: 'Kulgam'),
          ZoneCity(id: 'city_in_14_11', name: 'Kupwara'),
          ZoneCity(id: 'city_in_14_12', name: 'Poonch'),
          ZoneCity(id: 'city_in_14_13', name: 'Pulwama'),
          ZoneCity(id: 'city_in_14_14', name: 'Rajouri'),
          ZoneCity(id: 'city_in_14_15', name: 'Ramban'),
          ZoneCity(id: 'city_in_14_16', name: 'Reasi'),
          ZoneCity(id: 'city_in_14_17', name: 'Samba'),
          ZoneCity(id: 'city_in_14_18', name: 'Shopian'),
          ZoneCity(id: 'city_in_14_19', name: 'Srinagar'),
          ZoneCity(id: 'city_in_14_20', name: 'Udhampur'),
        ],
      ),
      ZoneState(
        id: 'state_in_15',
        name: 'Jharkhand',
        cities: [
          ZoneCity(id: 'city_in_15_1', name: 'Bokaro'),
          ZoneCity(id: 'city_in_15_2', name: 'Chatra'),
          ZoneCity(id: 'city_in_15_3', name: 'Deoghar'),
          ZoneCity(id: 'city_in_15_4', name: 'Dhanbad'),
          ZoneCity(id: 'city_in_15_5', name: 'Dumka'),
          ZoneCity(id: 'city_in_15_6', name: 'East Singhbhum'),
          ZoneCity(id: 'city_in_15_7', name: 'Giridih'),
          ZoneCity(id: 'city_in_15_8', name: 'Godda'),
          ZoneCity(id: 'city_in_15_9', name: 'Gumla'),
          ZoneCity(id: 'city_in_15_10', name: 'Hazaribagh'),
          ZoneCity(id: 'city_in_15_11', name: 'Jamshedpur'),
          ZoneCity(id: 'city_in_15_12', name: 'Jamtara'),
          ZoneCity(id: 'city_in_15_13', name: 'Khunti'),
          ZoneCity(id: 'city_in_15_14', name: 'Koderma'),
          ZoneCity(id: 'city_in_15_15', name: 'Latehar'),
          ZoneCity(id: 'city_in_15_16', name: 'Lohardaga'),
          ZoneCity(id: 'city_in_15_17', name: 'Pakur'),
          ZoneCity(id: 'city_in_15_18', name: 'Palamu'),
          ZoneCity(id: 'city_in_15_19', name: 'Ramgarh'),
          ZoneCity(id: 'city_in_15_20', name: 'Ranchi'),
          ZoneCity(id: 'city_in_15_21', name: 'Sahebganj'),
          ZoneCity(id: 'city_in_15_22', name: 'Seraikela-Kharsawan'),
          ZoneCity(id: 'city_in_15_23', name: 'Simdega'),
          ZoneCity(id: 'city_in_15_24', name: 'West Singhbhum'),
        ],
      ),
      ZoneState(
        id: 'state_in_16',
        name: 'Karnataka',
        cities: [
          ZoneCity(id: 'city_in_16_1', name: 'Bagalkot'),
          ZoneCity(id: 'city_in_16_2', name: 'Ballari'),
          ZoneCity(id: 'city_in_16_3', name: 'Belagavi'),
          ZoneCity(id: 'city_in_16_4', name: 'Bengaluru'),
          ZoneCity(id: 'city_in_16_5', name: 'Bengaluru Rural'),
          ZoneCity(id: 'city_in_16_6', name: 'Bidar'),
          ZoneCity(id: 'city_in_16_7', name: 'Chamarajanagar'),
          ZoneCity(id: 'city_in_16_8', name: 'Chikkaballapura'),
          ZoneCity(id: 'city_in_16_9', name: 'Chikkamagaluru'),
          ZoneCity(id: 'city_in_16_10', name: 'Chitradurga'),
          ZoneCity(id: 'city_in_16_11', name: 'Davangere'),
          ZoneCity(id: 'city_in_16_12', name: 'Dharwad'),
          ZoneCity(id: 'city_in_16_13', name: 'Gadag'),
          ZoneCity(id: 'city_in_16_14', name: 'Hassan'),
          ZoneCity(id: 'city_in_16_15', name: 'Haveri'),
          ZoneCity(id: 'city_in_16_16', name: 'Hubli-Dharwad'),
          ZoneCity(id: 'city_in_16_17', name: 'Kalaburagi'),
          ZoneCity(id: 'city_in_16_18', name: 'Kodagu'),
          ZoneCity(id: 'city_in_16_19', name: 'Kolar'),
          ZoneCity(id: 'city_in_16_20', name: 'Koppal'),
          ZoneCity(id: 'city_in_16_21', name: 'Mandya'),
          ZoneCity(id: 'city_in_16_22', name: 'Mangaluru'),
          ZoneCity(id: 'city_in_16_23', name: 'Mysuru'),
          ZoneCity(id: 'city_in_16_24', name: 'Raichur'),
          ZoneCity(id: 'city_in_16_25', name: 'Ramanagara'),
          ZoneCity(id: 'city_in_16_26', name: 'Shivamogga'),
          ZoneCity(id: 'city_in_16_27', name: 'Tumakuru'),
          ZoneCity(id: 'city_in_16_28', name: 'Uttara Kannada'),
          ZoneCity(id: 'city_in_16_29', name: 'Vijayanagara'),
          ZoneCity(id: 'city_in_16_30', name: 'Vijayapura'),
          ZoneCity(id: 'city_in_16_31', name: 'Yadgir'),
        ],
      ),
      ZoneState(
        id: 'state_in_17',
        name: 'Kerala',
        cities: [
          ZoneCity(id: 'city_in_17_1', name: 'Alappuzha'),
          ZoneCity(id: 'city_in_17_2', name: 'Ernakulam'),
          ZoneCity(id: 'city_in_17_3', name: 'Idukki'),
          ZoneCity(id: 'city_in_17_4', name: 'Kannur'),
          ZoneCity(id: 'city_in_17_5', name: 'Kasaragod'),
          ZoneCity(id: 'city_in_17_6', name: 'Kochi'),
          ZoneCity(id: 'city_in_17_7', name: 'Kollam'),
          ZoneCity(id: 'city_in_17_8', name: 'Kottayam'),
          ZoneCity(id: 'city_in_17_9', name: 'Kozhikode'),
          ZoneCity(id: 'city_in_17_10', name: 'Malappuram'),
          ZoneCity(id: 'city_in_17_11', name: 'Palakkad'),
          ZoneCity(id: 'city_in_17_12', name: 'Pathanamthitta'),
          ZoneCity(id: 'city_in_17_13', name: 'Thiruvananthapuram'),
          ZoneCity(id: 'city_in_17_14', name: 'Thrissur'),
          ZoneCity(id: 'city_in_17_15', name: 'Wayanad'),
        ],
      ),
      ZoneState(
        id: 'state_in_18',
        name: 'Ladakh',
        cities: [
          ZoneCity(id: 'city_in_18_1', name: 'Kargil'),
          ZoneCity(id: 'city_in_18_2', name: 'Leh'),
        ],
      ),
      ZoneState(
        id: 'state_in_19',
        name: 'Lakshadweep',
        cities: [
          ZoneCity(id: 'city_in_19_1', name: 'Kavaratti'),
        ],
      ),
      ZoneState(
        id: 'state_in_20',
        name: 'Madhya Pradesh',
        cities: [
          ZoneCity(id: 'city_in_20_1', name: 'Agar Malwa'),
          ZoneCity(id: 'city_in_20_2', name: 'Alirajpur'),
          ZoneCity(id: 'city_in_20_3', name: 'Anuppur'),
          ZoneCity(id: 'city_in_20_4', name: 'Ashoknagar'),
          ZoneCity(id: 'city_in_20_5', name: 'Balaghat'),
          ZoneCity(id: 'city_in_20_6', name: 'Barwani'),
          ZoneCity(id: 'city_in_20_7', name: 'Betul'),
          ZoneCity(id: 'city_in_20_8', name: 'Bhind'),
          ZoneCity(id: 'city_in_20_9', name: 'Bhopal'),
          ZoneCity(id: 'city_in_20_10', name: 'Burhanpur'),
          ZoneCity(id: 'city_in_20_11', name: 'Chhatarpur'),
          ZoneCity(id: 'city_in_20_12', name: 'Chhindwara'),
          ZoneCity(id: 'city_in_20_13', name: 'Damoh'),
          ZoneCity(id: 'city_in_20_14', name: 'Datia'),
          ZoneCity(id: 'city_in_20_15', name: 'Dewas'),
          ZoneCity(id: 'city_in_20_16', name: 'Dhar'),
          ZoneCity(id: 'city_in_20_17', name: 'Dindori'),
          ZoneCity(id: 'city_in_20_18', name: 'Guna'),
          ZoneCity(id: 'city_in_20_19', name: 'Gwalior'),
          ZoneCity(id: 'city_in_20_20', name: 'Harda'),
          ZoneCity(id: 'city_in_20_21', name: 'Hoshangabad'),
          ZoneCity(id: 'city_in_20_22', name: 'Indore'),
          ZoneCity(id: 'city_in_20_23', name: 'Jabalpur'),
          ZoneCity(id: 'city_in_20_24', name: 'Jhabua'),
          ZoneCity(id: 'city_in_20_25', name: 'Katni'),
          ZoneCity(id: 'city_in_20_26', name: 'Khandwa'),
          ZoneCity(id: 'city_in_20_27', name: 'Khargone'),
          ZoneCity(id: 'city_in_20_28', name: 'Mandla'),
          ZoneCity(id: 'city_in_20_29', name: 'Mandsaur'),
          ZoneCity(id: 'city_in_20_30', name: 'Morena'),
          ZoneCity(id: 'city_in_20_31', name: 'Narmadapuram'),
          ZoneCity(id: 'city_in_20_32', name: 'Narsinghpur'),
          ZoneCity(id: 'city_in_20_33', name: 'Neemuch'),
          ZoneCity(id: 'city_in_20_34', name: 'Panna'),
          ZoneCity(id: 'city_in_20_35', name: 'Raisen'),
          ZoneCity(id: 'city_in_20_36', name: 'Rajgarh'),
          ZoneCity(id: 'city_in_20_37', name: 'Ratlam'),
          ZoneCity(id: 'city_in_20_38', name: 'Rewa'),
          ZoneCity(id: 'city_in_20_39', name: 'Sagar'),
          ZoneCity(id: 'city_in_20_40', name: 'Satna'),
          ZoneCity(id: 'city_in_20_41', name: 'Sehore'),
          ZoneCity(id: 'city_in_20_42', name: 'Seoni'),
          ZoneCity(id: 'city_in_20_43', name: 'Shahdol'),
          ZoneCity(id: 'city_in_20_44', name: 'Shajapur'),
          ZoneCity(id: 'city_in_20_45', name: 'Shivpuri'),
          ZoneCity(id: 'city_in_20_46', name: 'Sidhi'),
          ZoneCity(id: 'city_in_20_47', name: 'Singrauli'),
          ZoneCity(id: 'city_in_20_48', name: 'Tikamgarh'),
          ZoneCity(id: 'city_in_20_49', name: 'Ujjain'),
          ZoneCity(id: 'city_in_20_50', name: 'Umaria'),
          ZoneCity(id: 'city_in_20_51', name: 'Vidisha'),
        ],
      ),
      ZoneState(
        id: 'state_in_21',
        name: 'Maharashtra',
        cities: [
          ZoneCity(id: 'city_in_21_1', name: 'Ahmednagar'),
          ZoneCity(id: 'city_in_21_2', name: 'Akola'),
          ZoneCity(id: 'city_in_21_3', name: 'Amravati'),
          ZoneCity(id: 'city_in_21_4', name: 'Aurangabad'),
          ZoneCity(id: 'city_in_21_5', name: 'Beed'),
          ZoneCity(id: 'city_in_21_6', name: 'Bhandara'),
          ZoneCity(id: 'city_in_21_7', name: 'Buldhana'),
          ZoneCity(id: 'city_in_21_8', name: 'Chandrapur'),
          ZoneCity(id: 'city_in_21_9', name: 'Dhule'),
          ZoneCity(id: 'city_in_21_10', name: 'Gadchiroli'),
          ZoneCity(id: 'city_in_21_11', name: 'Gondia'),
          ZoneCity(id: 'city_in_21_12', name: 'Hingoli'),
          ZoneCity(id: 'city_in_21_13', name: 'Jalgaon'),
          ZoneCity(id: 'city_in_21_14', name: 'Jalna'),
          ZoneCity(id: 'city_in_21_15', name: 'Kolhapur'),
          ZoneCity(id: 'city_in_21_16', name: 'Latur'),
          ZoneCity(id: 'city_in_21_17', name: 'Mumbai'),
          ZoneCity(id: 'city_in_21_18', name: 'Nagpur'),
          ZoneCity(id: 'city_in_21_19', name: 'Nanded'),
          ZoneCity(id: 'city_in_21_20', name: 'Nandurbar'),
          ZoneCity(id: 'city_in_21_21', name: 'Nashik'),
          ZoneCity(id: 'city_in_21_22', name: 'Osmanabad'),
          ZoneCity(id: 'city_in_21_23', name: 'Palghar'),
          ZoneCity(id: 'city_in_21_24', name: 'Parbhani'),
          ZoneCity(id: 'city_in_21_25', name: 'Pune'),
          ZoneCity(id: 'city_in_21_26', name: 'Raigad'),
          ZoneCity(id: 'city_in_21_27', name: 'Ratnagiri'),
          ZoneCity(id: 'city_in_21_28', name: 'Sangli'),
          ZoneCity(id: 'city_in_21_29', name: 'Satara'),
          ZoneCity(id: 'city_in_21_30', name: 'Sindhudurg'),
          ZoneCity(id: 'city_in_21_31', name: 'Solapur'),
          ZoneCity(id: 'city_in_21_32', name: 'Thane'),
          ZoneCity(id: 'city_in_21_33', name: 'Wardha'),
          ZoneCity(id: 'city_in_21_34', name: 'Washim'),
          ZoneCity(id: 'city_in_21_35', name: 'Yavatmal'),
        ],
      ),
      ZoneState(
        id: 'state_in_22',
        name: 'Manipur',
        cities: [
          ZoneCity(id: 'city_in_22_1', name: 'Bishnupur'),
          ZoneCity(id: 'city_in_22_2', name: 'Chandel'),
          ZoneCity(id: 'city_in_22_3', name: 'Churachandpur'),
          ZoneCity(id: 'city_in_22_4', name: 'Imphal'),
          ZoneCity(id: 'city_in_22_5', name: 'Imphal East'),
          ZoneCity(id: 'city_in_22_6', name: 'Jiribam'),
          ZoneCity(id: 'city_in_22_7', name: 'Kakching'),
          ZoneCity(id: 'city_in_22_8', name: 'Kamjong'),
          ZoneCity(id: 'city_in_22_9', name: 'Kangpokpi'),
          ZoneCity(id: 'city_in_22_10', name: 'Noney'),
          ZoneCity(id: 'city_in_22_11', name: 'Pherzawl'),
          ZoneCity(id: 'city_in_22_12', name: 'Senapati'),
          ZoneCity(id: 'city_in_22_13', name: 'Tamenglong'),
          ZoneCity(id: 'city_in_22_14', name: 'Tengnoupal'),
          ZoneCity(id: 'city_in_22_15', name: 'Thoubal'),
          ZoneCity(id: 'city_in_22_16', name: 'Ukhrul'),
        ],
      ),
      ZoneState(
        id: 'state_in_23',
        name: 'Meghalaya',
        cities: [
          ZoneCity(id: 'city_in_23_1', name: 'East Garo Hills'),
          ZoneCity(id: 'city_in_23_2', name: 'East Jaintia Hills'),
          ZoneCity(id: 'city_in_23_3', name: 'East Khasi Hills'),
          ZoneCity(id: 'city_in_23_4', name: 'Eastern West Khasi Hills'),
          ZoneCity(id: 'city_in_23_5', name: 'Mairang'),
          ZoneCity(id: 'city_in_23_6', name: 'North Garo Hills'),
          ZoneCity(id: 'city_in_23_7', name: 'Ribhoi'),
          ZoneCity(id: 'city_in_23_8', name: 'Shillong'),
          ZoneCity(id: 'city_in_23_9', name: 'South Garo Hills'),
          ZoneCity(id: 'city_in_23_10', name: 'West Garo Hills'),
          ZoneCity(id: 'city_in_23_11', name: 'West Jaintia Hills'),
          ZoneCity(id: 'city_in_23_12', name: 'West Khasi Hills'),
        ],
      ),
      ZoneState(
        id: 'state_in_24',
        name: 'Mizoram',
        cities: [
          ZoneCity(id: 'city_in_24_1', name: 'Aizawl'),
          ZoneCity(id: 'city_in_24_2', name: 'Champhai'),
          ZoneCity(id: 'city_in_24_3', name: 'Hnahthial'),
          ZoneCity(id: 'city_in_24_4', name: 'Khawzawl'),
          ZoneCity(id: 'city_in_24_5', name: 'Kolasib'),
          ZoneCity(id: 'city_in_24_6', name: 'Lawngtlai'),
          ZoneCity(id: 'city_in_24_7', name: 'Lunglei'),
          ZoneCity(id: 'city_in_24_8', name: 'Mamit'),
          ZoneCity(id: 'city_in_24_9', name: 'Saiha'),
          ZoneCity(id: 'city_in_24_10', name: 'Saitual'),
          ZoneCity(id: 'city_in_24_11', name: 'Serchhip'),
        ],
      ),
      ZoneState(
        id: 'state_in_25',
        name: 'Nagaland',
        cities: [
          ZoneCity(id: 'city_in_25_1', name: 'Dimapur'),
          ZoneCity(id: 'city_in_25_2', name: 'Kiphire'),
          ZoneCity(id: 'city_in_25_3', name: 'Kohima'),
          ZoneCity(id: 'city_in_25_4', name: 'Longleng'),
          ZoneCity(id: 'city_in_25_5', name: 'Mokokchung'),
          ZoneCity(id: 'city_in_25_6', name: 'Mon'),
          ZoneCity(id: 'city_in_25_7', name: 'Niuland'),
          ZoneCity(id: 'city_in_25_8', name: 'Peren'),
          ZoneCity(id: 'city_in_25_9', name: 'Phek'),
          ZoneCity(id: 'city_in_25_10', name: 'Tseminyu'),
          ZoneCity(id: 'city_in_25_11', name: 'Tuensang'),
          ZoneCity(id: 'city_in_25_12', name: 'Wokha'),
          ZoneCity(id: 'city_in_25_13', name: 'Zunheboto'),
        ],
      ),
      ZoneState(
        id: 'state_in_26',
        name: 'Odisha',
        cities: [
          ZoneCity(id: 'city_in_26_1', name: 'Angul'),
          ZoneCity(id: 'city_in_26_2', name: 'Balasore'),
          ZoneCity(id: 'city_in_26_3', name: 'Bargarh'),
          ZoneCity(id: 'city_in_26_4', name: 'Berhampur'),
          ZoneCity(id: 'city_in_26_5', name: 'Bhubaneswar'),
          ZoneCity(id: 'city_in_26_6', name: 'Bolangir'),
          ZoneCity(id: 'city_in_26_7', name: 'Boudh'),
          ZoneCity(id: 'city_in_26_8', name: 'Boudh'),
          ZoneCity(id: 'city_in_26_9', name: 'Cuttack'),
          ZoneCity(id: 'city_in_26_10', name: 'Dhenkanal'),
          ZoneCity(id: 'city_in_26_11', name: 'Gajapati'),
          ZoneCity(id: 'city_in_26_12', name: 'Jagatsinghpur'),
          ZoneCity(id: 'city_in_26_13', name: 'Jajpur'),
          ZoneCity(id: 'city_in_26_14', name: 'Jharsuguda'),
          ZoneCity(id: 'city_in_26_15', name: 'Kalahandi'),
          ZoneCity(id: 'city_in_26_16', name: 'Kandhamal'),
          ZoneCity(id: 'city_in_26_17', name: 'Kendujhar'),
          ZoneCity(id: 'city_in_26_18', name: 'Khordha'),
          ZoneCity(id: 'city_in_26_19', name: 'Koraput'),
          ZoneCity(id: 'city_in_26_20', name: 'Malkangiri'),
          ZoneCity(id: 'city_in_26_21', name: 'Mayurbhanj'),
          ZoneCity(id: 'city_in_26_22', name: 'Nabarangapur'),
          ZoneCity(id: 'city_in_26_23', name: 'Nayagarh'),
          ZoneCity(id: 'city_in_26_24', name: 'Nuapada'),
          ZoneCity(id: 'city_in_26_25', name: 'Paradip'),
          ZoneCity(id: 'city_in_26_26', name: 'Puri'),
          ZoneCity(id: 'city_in_26_27', name: 'Rayagada'),
          ZoneCity(id: 'city_in_26_28', name: 'Rourkela'),
          ZoneCity(id: 'city_in_26_29', name: 'Sambalpur'),
          ZoneCity(id: 'city_in_26_30', name: 'Sonepur'),
          ZoneCity(id: 'city_in_26_31', name: 'Sundargarh'),
        ],
      ),
      ZoneState(
        id: 'state_in_27',
        name: 'Puducherry',
        cities: [
          ZoneCity(id: 'city_in_27_1', name: 'Puducherry'),
        ],
      ),
      ZoneState(
        id: 'state_in_28',
        name: 'Punjab',
        cities: [
          ZoneCity(id: 'city_in_28_1', name: 'Amritsar'),
          ZoneCity(id: 'city_in_28_2', name: 'Barnala'),
          ZoneCity(id: 'city_in_28_3', name: 'Bathinda'),
          ZoneCity(id: 'city_in_28_4', name: 'Faridkot'),
          ZoneCity(id: 'city_in_28_5', name: 'Fatehgarh Sahib'),
          ZoneCity(id: 'city_in_28_6', name: 'Fazilka'),
          ZoneCity(id: 'city_in_28_7', name: 'Firozpur'),
          ZoneCity(id: 'city_in_28_8', name: 'Gurdaspur'),
          ZoneCity(id: 'city_in_28_9', name: 'Hoshiarpur'),
          ZoneCity(id: 'city_in_28_10', name: 'Jalandhar'),
          ZoneCity(id: 'city_in_28_11', name: 'Kapurthala'),
          ZoneCity(id: 'city_in_28_12', name: 'Ludhiana'),
          ZoneCity(id: 'city_in_28_13', name: 'Malerkotla'),
          ZoneCity(id: 'city_in_28_14', name: 'Mansa'),
          ZoneCity(id: 'city_in_28_15', name: 'Moga'),
          ZoneCity(id: 'city_in_28_16', name: 'Mohali'),
          ZoneCity(id: 'city_in_28_17', name: 'Muktsar'),
          ZoneCity(id: 'city_in_28_18', name: 'Nawanshahr'),
          ZoneCity(id: 'city_in_28_19', name: 'Pathankot'),
          ZoneCity(id: 'city_in_28_20', name: 'Patiala'),
          ZoneCity(id: 'city_in_28_21', name: 'Rupnagar'),
          ZoneCity(id: 'city_in_28_22', name: 'Sangrur'),
          ZoneCity(id: 'city_in_28_23', name: 'Tarn Taran'),
        ],
      ),
      ZoneState(
        id: 'state_in_29',
        name: 'Rajasthan',
        cities: [
          ZoneCity(id: 'city_in_29_1', name: 'Ajmer'),
          ZoneCity(id: 'city_in_29_2', name: 'Alwar'),
          ZoneCity(id: 'city_in_29_3', name: 'Banswara'),
          ZoneCity(id: 'city_in_29_4', name: 'Baran'),
          ZoneCity(id: 'city_in_29_5', name: 'Barmer'),
          ZoneCity(id: 'city_in_29_6', name: 'Bharatpur'),
          ZoneCity(id: 'city_in_29_7', name: 'Bhilwara'),
          ZoneCity(id: 'city_in_29_8', name: 'Bikaner'),
          ZoneCity(id: 'city_in_29_9', name: 'Bundi'),
          ZoneCity(id: 'city_in_29_10', name: 'Chittorgarh'),
          ZoneCity(id: 'city_in_29_11', name: 'Churu'),
          ZoneCity(id: 'city_in_29_12', name: 'Dausa'),
          ZoneCity(id: 'city_in_29_13', name: 'Dholpur'),
          ZoneCity(id: 'city_in_29_14', name: 'Dungarpur'),
          ZoneCity(id: 'city_in_29_15', name: 'Ganganagar'),
          ZoneCity(id: 'city_in_29_16', name: 'Hanumangarh'),
          ZoneCity(id: 'city_in_29_17', name: 'Jaipur'),
          ZoneCity(id: 'city_in_29_18', name: 'Jaisalmer'),
          ZoneCity(id: 'city_in_29_19', name: 'Jalore'),
          ZoneCity(id: 'city_in_29_20', name: 'Jhalawar'),
          ZoneCity(id: 'city_in_29_21', name: 'Jhunjhunu'),
          ZoneCity(id: 'city_in_29_22', name: 'Jodhpur'),
          ZoneCity(id: 'city_in_29_23', name: 'Karauli'),
          ZoneCity(id: 'city_in_29_24', name: 'Kota'),
          ZoneCity(id: 'city_in_29_25', name: 'Nagaur'),
          ZoneCity(id: 'city_in_29_26', name: 'Pali'),
          ZoneCity(id: 'city_in_29_27', name: 'Pratapgarh'),
          ZoneCity(id: 'city_in_29_28', name: 'Rajsamand'),
          ZoneCity(id: 'city_in_29_29', name: 'Sawai Madhopur'),
          ZoneCity(id: 'city_in_29_30', name: 'Sikar'),
          ZoneCity(id: 'city_in_29_31', name: 'Sirohi'),
          ZoneCity(id: 'city_in_29_32', name: 'Tonk'),
          ZoneCity(id: 'city_in_29_33', name: 'Udaipur'),
        ],
      ),
      ZoneState(
        id: 'state_in_30',
        name: 'Sikkim',
        cities: [
          ZoneCity(id: 'city_in_30_1', name: 'East Sikkim'),
          ZoneCity(id: 'city_in_30_2', name: 'Gangtok'),
          ZoneCity(id: 'city_in_30_3', name: 'North Sikkim'),
          ZoneCity(id: 'city_in_30_4', name: 'Pakyong'),
          ZoneCity(id: 'city_in_30_5', name: 'Soreng'),
          ZoneCity(id: 'city_in_30_6', name: 'South Sikkim'),
          ZoneCity(id: 'city_in_30_7', name: 'West Sikkim'),
        ],
      ),
      ZoneState(
        id: 'state_in_31',
        name: 'Tamil Nadu',
        cities: [
          ZoneCity(id: 'city_in_31_1', name: 'Ariyalur'),
          ZoneCity(id: 'city_in_31_2', name: 'Chengalpattu'),
          ZoneCity(id: 'city_in_31_3', name: 'Chennai'),
          ZoneCity(id: 'city_in_31_4', name: 'Coimbatore'),
          ZoneCity(id: 'city_in_31_5', name: 'Cuddalore'),
          ZoneCity(id: 'city_in_31_6', name: 'Dharmapuri'),
          ZoneCity(id: 'city_in_31_7', name: 'Dindigul'),
          ZoneCity(id: 'city_in_31_8', name: 'Erode'),
          ZoneCity(id: 'city_in_31_9', name: 'Kallakurichi'),
          ZoneCity(id: 'city_in_31_10', name: 'Kancheepuram'),
          ZoneCity(id: 'city_in_31_11', name: 'Kanniyakumari'),
          ZoneCity(id: 'city_in_31_12', name: 'Karur'),
          ZoneCity(id: 'city_in_31_13', name: 'Krishnagiri'),
          ZoneCity(id: 'city_in_31_14', name: 'Madurai'),
          ZoneCity(id: 'city_in_31_15', name: 'Mayiladuthurai'),
          ZoneCity(id: 'city_in_31_16', name: 'Nagapattinam'),
          ZoneCity(id: 'city_in_31_17', name: 'Namakkal'),
          ZoneCity(id: 'city_in_31_18', name: 'Nilgiris'),
          ZoneCity(id: 'city_in_31_19', name: 'Perambalur'),
          ZoneCity(id: 'city_in_31_20', name: 'Pudukkottai'),
          ZoneCity(id: 'city_in_31_21', name: 'Ramanathapuram'),
          ZoneCity(id: 'city_in_31_22', name: 'Ranipet'),
          ZoneCity(id: 'city_in_31_23', name: 'Salem'),
          ZoneCity(id: 'city_in_31_24', name: 'Sivaganga'),
          ZoneCity(id: 'city_in_31_25', name: 'Tenkasi'),
          ZoneCity(id: 'city_in_31_26', name: 'Thanjavur'),
          ZoneCity(id: 'city_in_31_27', name: 'Theni'),
          ZoneCity(id: 'city_in_31_28', name: 'Thoothukudi'),
          ZoneCity(id: 'city_in_31_29', name: 'Tiruchirappalli'),
          ZoneCity(id: 'city_in_31_30', name: 'Tirunelveli'),
          ZoneCity(id: 'city_in_31_31', name: 'Tirupathur'),
          ZoneCity(id: 'city_in_31_32', name: 'Tirupur'),
          ZoneCity(id: 'city_in_31_33', name: 'Tiruvannamalai'),
          ZoneCity(id: 'city_in_31_34', name: 'Tiruvarur'),
          ZoneCity(id: 'city_in_31_35', name: 'Vellore'),
          ZoneCity(id: 'city_in_31_36', name: 'Villupuram'),
          ZoneCity(id: 'city_in_31_37', name: 'Virudhunagar'),
        ],
      ),
      ZoneState(
        id: 'state_in_32',
        name: 'Telangana',
        cities: [
          ZoneCity(id: 'city_in_32_1', name: 'Adilabad'),
          ZoneCity(id: 'city_in_32_2', name: 'Asifabad'),
          ZoneCity(id: 'city_in_32_3', name: 'Bhadradri Kothagudem'),
          ZoneCity(id: 'city_in_32_4', name: 'Bhupalpally'),
          ZoneCity(id: 'city_in_32_5', name: 'Hyderabad'),
          ZoneCity(id: 'city_in_32_6', name: 'Jagtial'),
          ZoneCity(id: 'city_in_32_7', name: 'Jayashankar'),
          ZoneCity(id: 'city_in_32_8', name: 'Jogulamba Gadwal'),
          ZoneCity(id: 'city_in_32_9', name: 'Kamareddy'),
          ZoneCity(id: 'city_in_32_10', name: 'Karimnagar'),
          ZoneCity(id: 'city_in_32_11', name: 'Khammam'),
          ZoneCity(id: 'city_in_32_12', name: 'Mahabubabad'),
          ZoneCity(id: 'city_in_32_13', name: 'Mahbubnagar'),
          ZoneCity(id: 'city_in_32_14', name: 'Mancherial'),
          ZoneCity(id: 'city_in_32_15', name: 'Medak'),
          ZoneCity(id: 'city_in_32_16', name: 'Medchal-Malkajgiri'),
          ZoneCity(id: 'city_in_32_17', name: 'Mulugu'),
          ZoneCity(id: 'city_in_32_18', name: 'Nagar Kurnool'),
          ZoneCity(id: 'city_in_32_19', name: 'Nagarkurnool'),
          ZoneCity(id: 'city_in_32_20', name: 'Nalgonda'),
          ZoneCity(id: 'city_in_32_21', name: 'Narayanpet'),
          ZoneCity(id: 'city_in_32_22', name: 'Narayanpet'),
          ZoneCity(id: 'city_in_32_23', name: 'Nirmal'),
          ZoneCity(id: 'city_in_32_24', name: 'Nizamabad'),
          ZoneCity(id: 'city_in_32_25', name: 'Peddapalli'),
          ZoneCity(id: 'city_in_32_26', name: 'Rajanna Sircilla'),
          ZoneCity(id: 'city_in_32_27', name: 'Rangareddy'),
          ZoneCity(id: 'city_in_32_28', name: 'Sangareddy'),
          ZoneCity(id: 'city_in_32_29', name: 'Suryapet'),
          ZoneCity(id: 'city_in_32_30', name: 'Vikarabad'),
          ZoneCity(id: 'city_in_32_31', name: 'Wanaparthy'),
          ZoneCity(id: 'city_in_32_32', name: 'Warangal'),
          ZoneCity(id: 'city_in_32_33', name: 'Yadadri'),
        ],
      ),
      ZoneState(
        id: 'state_in_33',
        name: 'Tripura',
        cities: [
          ZoneCity(id: 'city_in_33_1', name: 'Agartala'),
          ZoneCity(id: 'city_in_33_2', name: 'Dhalai'),
          ZoneCity(id: 'city_in_33_3', name: 'Gomati'),
          ZoneCity(id: 'city_in_33_4', name: 'Khowai'),
          ZoneCity(id: 'city_in_33_5', name: 'North Tripura'),
          ZoneCity(id: 'city_in_33_6', name: 'Sepahijala'),
          ZoneCity(id: 'city_in_33_7', name: 'South Tripura'),
          ZoneCity(id: 'city_in_33_8', name: 'Unakoti'),
          ZoneCity(id: 'city_in_33_9', name: 'West Tripura'),
        ],
      ),
      ZoneState(
        id: 'state_in_34',
        name: 'Uttar Pradesh',
        cities: [
          ZoneCity(id: 'city_in_34_1', name: 'Agra'),
          ZoneCity(id: 'city_in_34_2', name: 'Aligarh'),
          ZoneCity(id: 'city_in_34_3', name: 'Ambedkar Nagar'),
          ZoneCity(id: 'city_in_34_4', name: 'Amroha'),
          ZoneCity(id: 'city_in_34_5', name: 'Auraiya'),
          ZoneCity(id: 'city_in_34_6', name: 'Azamgarh'),
          ZoneCity(id: 'city_in_34_7', name: 'Bagpat'),
          ZoneCity(id: 'city_in_34_8', name: 'Bahraich'),
          ZoneCity(id: 'city_in_34_9', name: 'Ballia'),
          ZoneCity(id: 'city_in_34_10', name: 'Balrampur'),
          ZoneCity(id: 'city_in_34_11', name: 'Banda'),
          ZoneCity(id: 'city_in_34_12', name: 'Bareilly'),
          ZoneCity(id: 'city_in_34_13', name: 'Basti'),
          ZoneCity(id: 'city_in_34_14', name: 'Bhadohi'),
          ZoneCity(id: 'city_in_34_15', name: 'Budaun'),
          ZoneCity(id: 'city_in_34_16', name: 'Bulandshahr'),
          ZoneCity(id: 'city_in_34_17', name: 'Chandauli'),
          ZoneCity(id: 'city_in_34_18', name: 'Chitrakoot'),
          ZoneCity(id: 'city_in_34_19', name: 'Deoria'),
          ZoneCity(id: 'city_in_34_20', name: 'Etah'),
          ZoneCity(id: 'city_in_34_21', name: 'Etawah'),
          ZoneCity(id: 'city_in_34_22', name: 'Faizabad'),
          ZoneCity(id: 'city_in_34_23', name: 'Farrukhabad'),
          ZoneCity(id: 'city_in_34_24', name: 'Fatehpur'),
          ZoneCity(id: 'city_in_34_25', name: 'Firozabad'),
          ZoneCity(id: 'city_in_34_26', name: 'Gautam Buddha Nagar'),
          ZoneCity(id: 'city_in_34_27', name: 'Ghaziabad'),
          ZoneCity(id: 'city_in_34_28', name: 'Ghazipur'),
          ZoneCity(id: 'city_in_34_29', name: 'Gonda'),
          ZoneCity(id: 'city_in_34_30', name: 'Gorakhpur'),
          ZoneCity(id: 'city_in_34_31', name: 'Hamirpur'),
          ZoneCity(id: 'city_in_34_32', name: 'Hapur'),
          ZoneCity(id: 'city_in_34_33', name: 'Hardoi'),
          ZoneCity(id: 'city_in_34_34', name: 'Hathras'),
          ZoneCity(id: 'city_in_34_35', name: 'Jaunpur'),
          ZoneCity(id: 'city_in_34_36', name: 'Jhansi'),
          ZoneCity(id: 'city_in_34_37', name: 'Kannauj'),
          ZoneCity(id: 'city_in_34_38', name: 'Kanpur'),
          ZoneCity(id: 'city_in_34_39', name: 'Kanpur Dehat'),
          ZoneCity(id: 'city_in_34_40', name: 'Kasganj'),
          ZoneCity(id: 'city_in_34_41', name: 'Kaushambi'),
          ZoneCity(id: 'city_in_34_42', name: 'Kushinagar'),
          ZoneCity(id: 'city_in_34_43', name: 'Lakhimpur Kheri'),
          ZoneCity(id: 'city_in_34_44', name: 'Lalitpur'),
          ZoneCity(id: 'city_in_34_45', name: 'Lucknow'),
          ZoneCity(id: 'city_in_34_46', name: 'Maharajganj'),
          ZoneCity(id: 'city_in_34_47', name: 'Mahoba'),
          ZoneCity(id: 'city_in_34_48', name: 'Mainpuri'),
          ZoneCity(id: 'city_in_34_49', name: 'Mathura'),
          ZoneCity(id: 'city_in_34_50', name: 'Mau'),
          ZoneCity(id: 'city_in_34_51', name: 'Meerut'),
          ZoneCity(id: 'city_in_34_52', name: 'Mirzapur'),
          ZoneCity(id: 'city_in_34_53', name: 'Moradabad'),
          ZoneCity(id: 'city_in_34_54', name: 'Muzaffarnagar'),
          ZoneCity(id: 'city_in_34_55', name: 'Noida'),
          ZoneCity(id: 'city_in_34_56', name: 'Pilibhit'),
          ZoneCity(id: 'city_in_34_57', name: 'Pratapgarh'),
          ZoneCity(id: 'city_in_34_58', name: 'Prayagraj'),
          ZoneCity(id: 'city_in_34_59', name: 'Rae Bareli'),
          ZoneCity(id: 'city_in_34_60', name: 'Rampur'),
          ZoneCity(id: 'city_in_34_61', name: 'Saharanpur'),
          ZoneCity(id: 'city_in_34_62', name: 'Sambhal'),
          ZoneCity(id: 'city_in_34_63', name: 'Sant Kabir Nagar'),
          ZoneCity(id: 'city_in_34_64', name: 'Shahjahanpur'),
          ZoneCity(id: 'city_in_34_65', name: 'Shravasti'),
          ZoneCity(id: 'city_in_34_66', name: 'Siddharthnagar'),
          ZoneCity(id: 'city_in_34_67', name: 'Sitapur'),
          ZoneCity(id: 'city_in_34_68', name: 'Sonbhadra'),
          ZoneCity(id: 'city_in_34_69', name: 'Sultanpur'),
          ZoneCity(id: 'city_in_34_70', name: 'Unnao'),
          ZoneCity(id: 'city_in_34_71', name: 'Varanasi'),
        ],
      ),
      ZoneState(
        id: 'state_in_35',
        name: 'Uttarakhand',
        cities: [
          ZoneCity(id: 'city_in_35_1', name: 'Almora'),
          ZoneCity(id: 'city_in_35_2', name: 'Bageshwar'),
          ZoneCity(id: 'city_in_35_3', name: 'Chamoli'),
          ZoneCity(id: 'city_in_35_4', name: 'Champawat'),
          ZoneCity(id: 'city_in_35_5', name: 'Dehradun'),
          ZoneCity(id: 'city_in_35_6', name: 'Haridwar'),
          ZoneCity(id: 'city_in_35_7', name: 'Nainital'),
          ZoneCity(id: 'city_in_35_8', name: 'Pauri Garhwal'),
          ZoneCity(id: 'city_in_35_9', name: 'Pithoragarh'),
          ZoneCity(id: 'city_in_35_10', name: 'Roorkee'),
          ZoneCity(id: 'city_in_35_11', name: 'Rudraprayag'),
          ZoneCity(id: 'city_in_35_12', name: 'Tehri Garhwal'),
          ZoneCity(id: 'city_in_35_13', name: 'Udham Singh Nagar'),
          ZoneCity(id: 'city_in_35_14', name: 'Uttarkashi'),
        ],
      ),
      ZoneState(
        id: 'state_in_36',
        name: 'West Bengal',
        cities: [
          ZoneCity(id: 'city_in_36_1', name: 'Alipurduar'),
          ZoneCity(id: 'city_in_36_2', name: 'Asansol'),
          ZoneCity(id: 'city_in_36_3', name: 'Bankura'),
          ZoneCity(id: 'city_in_36_4', name: 'Bardhaman'),
          ZoneCity(id: 'city_in_36_5', name: 'Birbhum'),
          ZoneCity(id: 'city_in_36_6', name: 'Cooch Behar'),
          ZoneCity(id: 'city_in_36_7', name: 'Darjeeling'),
          ZoneCity(id: 'city_in_36_8', name: 'Durgapur'),
          ZoneCity(id: 'city_in_36_9', name: 'Haldia'),
          ZoneCity(id: 'city_in_36_10', name: 'Hooghly'),
          ZoneCity(id: 'city_in_36_11', name: 'Howrah'),
          ZoneCity(id: 'city_in_36_12', name: 'Jalpaiguri'),
          ZoneCity(id: 'city_in_36_13', name: 'Jhargram'),
          ZoneCity(id: 'city_in_36_14', name: 'Kharagpur'),
          ZoneCity(id: 'city_in_36_15', name: 'Kolkata'),
          ZoneCity(id: 'city_in_36_16', name: 'Malda'),
          ZoneCity(id: 'city_in_36_17', name: 'Murshidabad'),
          ZoneCity(id: 'city_in_36_18', name: 'Nadia'),
          ZoneCity(id: 'city_in_36_19', name: 'North 24 Parganas'),
          ZoneCity(id: 'city_in_36_20', name: 'North Dinajpur'),
          ZoneCity(id: 'city_in_36_21', name: 'Purulia'),
          ZoneCity(id: 'city_in_36_22', name: 'Siliguri'),
          ZoneCity(id: 'city_in_36_23', name: 'South 24 Parganas'),
          ZoneCity(id: 'city_in_36_24', name: 'South Dinajpur'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_100',
    name: 'China',
    states: [
      ZoneState(
        id: 'state_w_100_1',
        name: 'China Cities',
        cities: [
          ZoneCity(id: 'city_w_100_1_1', name: 'Shanghai'),
          ZoneCity(id: 'city_w_100_1_2', name: 'Beijing'),
          ZoneCity(id: 'city_w_100_1_3', name: 'Guangzhou'),
          ZoneCity(id: 'city_w_100_1_4', name: 'Shenzhen'),
          ZoneCity(id: 'city_w_100_1_5', name: 'Chengdu'),
          ZoneCity(id: 'city_w_100_1_6', name: 'Tianjin'),
          ZoneCity(id: 'city_w_100_1_7', name: 'Wuhan'),
          ZoneCity(id: 'city_w_100_1_8', name: 'Chongqing'),
          ZoneCity(id: 'city_w_100_1_9', name: "Xi'an"),
          ZoneCity(id: 'city_w_100_1_10', name: 'Hangzhou'),
          ZoneCity(id: 'city_w_100_1_11', name: 'Ningbo'),
          ZoneCity(id: 'city_w_100_1_12', name: 'Qingdao'),
          ZoneCity(id: 'city_w_100_1_13', name: 'Dalian'),
          ZoneCity(id: 'city_w_100_1_14', name: 'Nanjing'),
          ZoneCity(id: 'city_w_100_1_15', name: 'Kunming'),
          ZoneCity(id: 'city_w_100_1_16', name: 'Harbin'),
          ZoneCity(id: 'city_w_100_1_17', name: 'Hong Kong'),
          ZoneCity(id: 'city_w_100_1_18', name: 'Macau'),
          ZoneCity(id: 'city_w_100_1_19', name: 'Urumqi'),
          ZoneCity(id: 'city_w_100_1_20', name: 'Lhasa'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_101',
    name: 'Japan',
    states: [
      ZoneState(
        id: 'state_w_101_1',
        name: 'Japan Cities',
        cities: [
          ZoneCity(id: 'city_w_101_1_1', name: 'Tokyo'),
          ZoneCity(id: 'city_w_101_1_2', name: 'Osaka'),
          ZoneCity(id: 'city_w_101_1_3', name: 'Nagoya'),
          ZoneCity(id: 'city_w_101_1_4', name: 'Yokohama'),
          ZoneCity(id: 'city_w_101_1_5', name: 'Kobe'),
          ZoneCity(id: 'city_w_101_1_6', name: 'Fukuoka'),
          ZoneCity(id: 'city_w_101_1_7', name: 'Sapporo'),
          ZoneCity(id: 'city_w_101_1_8', name: 'Hiroshima'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_102',
    name: 'South Korea',
    states: [
      ZoneState(
        id: 'state_w_102_1',
        name: 'South Korea Cities',
        cities: [
          ZoneCity(id: 'city_w_102_1_1', name: 'Seoul'),
          ZoneCity(id: 'city_w_102_1_2', name: 'Busan'),
          ZoneCity(id: 'city_w_102_1_3', name: 'Incheon'),
          ZoneCity(id: 'city_w_102_1_4', name: 'Daegu'),
          ZoneCity(id: 'city_w_102_1_5', name: 'Incheon'),
          ZoneCity(id: 'city_w_102_1_6', name: 'Gwangyang'),
          ZoneCity(id: 'city_w_102_1_7', name: 'Ulsan'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_103',
    name: 'Singapore',
    states: [
      ZoneState(
        id: 'state_w_103_1',
        name: 'Singapore Cities',
        cities: [
          ZoneCity(id: 'city_w_103_1_1', name: 'Singapore'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_104',
    name: 'Thailand',
    states: [
      ZoneState(
        id: 'state_w_104_1',
        name: 'Thailand Cities',
        cities: [
          ZoneCity(id: 'city_w_104_1_1', name: 'Bangkok'),
          ZoneCity(id: 'city_w_104_1_2', name: 'Laem Chabang'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_105',
    name: 'Malaysia',
    states: [
      ZoneState(
        id: 'state_w_105_1',
        name: 'Malaysia Cities',
        cities: [
          ZoneCity(id: 'city_w_105_1_1', name: 'Kuala Lumpur'),
          ZoneCity(id: 'city_w_105_1_2', name: 'Port Klang'),
          ZoneCity(id: 'city_w_105_1_3', name: 'Penang'),
          ZoneCity(id: 'city_w_105_1_4', name: 'Klang'),
          ZoneCity(id: 'city_w_105_1_5', name: 'Tanjung Pelepas'),
          ZoneCity(id: 'city_w_105_1_6', name: 'Johor Bahru'),
          ZoneCity(id: 'city_w_105_1_7', name: 'Port Klang'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_106',
    name: 'Indonesia',
    states: [
      ZoneState(
        id: 'state_w_106_1',
        name: 'Indonesia Cities',
        cities: [
          ZoneCity(id: 'city_w_106_1_1', name: 'Jakarta'),
          ZoneCity(id: 'city_w_106_1_2', name: 'Tanjung Priok'),
          ZoneCity(id: 'city_w_106_1_3', name: 'Surabaya'),
          ZoneCity(id: 'city_w_106_1_4', name: 'Medan'),
          ZoneCity(id: 'city_w_106_1_5', name: 'Makassar'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_107',
    name: 'Philippines',
    states: [
      ZoneState(
        id: 'state_w_107_1',
        name: 'Philippines Cities',
        cities: [
          ZoneCity(id: 'city_w_107_1_1', name: 'Manila'),
          ZoneCity(id: 'city_w_107_1_2', name: 'Cebu'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_108',
    name: 'Vietnam',
    states: [
      ZoneState(
        id: 'state_w_108_1',
        name: 'Vietnam Cities',
        cities: [
          ZoneCity(id: 'city_w_108_1_1', name: 'Ho Chi Minh City'),
          ZoneCity(id: 'city_w_108_1_2', name: 'Hanoi'),
          ZoneCity(id: 'city_w_108_1_3', name: 'Da Nang'),
          ZoneCity(id: 'city_w_108_1_4', name: 'Haiphong'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_109',
    name: 'Myanmar',
    states: [
      ZoneState(
        id: 'state_w_109_1',
        name: 'Myanmar Cities',
        cities: [
          ZoneCity(id: 'city_w_109_1_1', name: 'Yangon'),
          ZoneCity(id: 'city_w_109_1_2', name: 'Mandalay'),
          ZoneCity(id: 'city_w_109_1_3', name: 'Naypyidaw'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_110',
    name: 'Cambodia',
    states: [
      ZoneState(
        id: 'state_w_110_1',
        name: 'Cambodia Cities',
        cities: [
          ZoneCity(id: 'city_w_110_1_1', name: 'Phnom Penh'),
          ZoneCity(id: 'city_w_110_1_2', name: 'Sihanoukville'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_111',
    name: 'Laos',
    states: [
      ZoneState(
        id: 'state_w_111_1',
        name: 'Laos Cities',
        cities: [
          ZoneCity(id: 'city_w_111_1_1', name: 'Vientiane'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_112',
    name: 'Brunei',
    states: [
      ZoneState(
        id: 'state_w_112_1',
        name: 'Brunei Cities',
        cities: [
          ZoneCity(id: 'city_w_112_1_1', name: 'Bandar Seri Begawan'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_113',
    name: 'Timor-Leste',
    states: [
      ZoneState(
        id: 'state_w_113_1',
        name: 'Timor-Leste Cities',
        cities: [
          ZoneCity(id: 'city_w_113_1_1', name: 'Dili'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_114',
    name: 'Pakistan',
    states: [
      ZoneState(
        id: 'state_w_114_1',
        name: 'Pakistan Cities',
        cities: [
          ZoneCity(id: 'city_w_114_1_1', name: 'Karachi'),
          ZoneCity(id: 'city_w_114_1_2', name: 'Lahore'),
          ZoneCity(id: 'city_w_114_1_3', name: 'Islamabad'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_115',
    name: 'Bangladesh',
    states: [
      ZoneState(
        id: 'state_w_115_1',
        name: 'Bangladesh Cities',
        cities: [
          ZoneCity(id: 'city_w_115_1_1', name: 'Dhaka'),
          ZoneCity(id: 'city_w_115_1_2', name: 'Chittagong'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_116',
    name: 'Sri Lanka',
    states: [
      ZoneState(
        id: 'state_w_116_1',
        name: 'Sri Lanka Cities',
        cities: [
          ZoneCity(id: 'city_w_116_1_1', name: 'Colombo'),
          ZoneCity(id: 'city_w_116_1_2', name: 'Hambantota'),
          ZoneCity(id: 'city_w_116_1_3', name: 'Colombo'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_117',
    name: 'Nepal',
    states: [
      ZoneState(
        id: 'state_w_117_1',
        name: 'Nepal Cities',
        cities: [
          ZoneCity(id: 'city_w_117_1_1', name: 'Kathmandu'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_118',
    name: 'Bhutan',
    states: [
      ZoneState(
        id: 'state_w_118_1',
        name: 'Bhutan Cities',
        cities: [
          ZoneCity(id: 'city_w_118_1_1', name: 'Thimphu'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_119',
    name: 'Maldives',
    states: [
      ZoneState(
        id: 'state_w_119_1',
        name: 'Maldives Cities',
        cities: [
          ZoneCity(id: 'city_w_119_1_1', name: 'Malé'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_120',
    name: 'Afghanistan',
    states: [
      ZoneState(
        id: 'state_w_120_1',
        name: 'Afghanistan Cities',
        cities: [
          ZoneCity(id: 'city_w_120_1_1', name: 'Kabul'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_121',
    name: 'Oman',
    states: [
      ZoneState(
        id: 'state_w_121_1',
        name: 'Oman Cities',
        cities: [
          ZoneCity(id: 'city_w_121_1_1', name: 'Muscat'),
          ZoneCity(id: 'city_w_121_1_2', name: 'Salalah'),
          ZoneCity(id: 'city_w_121_1_3', name: 'Salalah'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_122',
    name: 'UAE',
    states: [
      ZoneState(
        id: 'state_w_122_1',
        name: 'UAE Cities',
        cities: [
          ZoneCity(id: 'city_w_122_1_1', name: 'Dubai'),
          ZoneCity(id: 'city_w_122_1_2', name: 'Abu Dhabi'),
          ZoneCity(id: 'city_w_122_1_3', name: 'Sharjah'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_123',
    name: 'Saudi Arabia',
    states: [
      ZoneState(
        id: 'state_w_123_1',
        name: 'Saudi Arabia Cities',
        cities: [
          ZoneCity(id: 'city_w_123_1_1', name: 'Riyadh'),
          ZoneCity(id: 'city_w_123_1_2', name: 'Jeddah'),
          ZoneCity(id: 'city_w_123_1_3', name: 'Dammam'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_124',
    name: 'Qatar',
    states: [
      ZoneState(
        id: 'state_w_124_1',
        name: 'Qatar Cities',
        cities: [
          ZoneCity(id: 'city_w_124_1_1', name: 'Doha'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_125',
    name: 'Kuwait',
    states: [
      ZoneState(
        id: 'state_w_125_1',
        name: 'Kuwait Cities',
        cities: [
          ZoneCity(id: 'city_w_125_1_1', name: 'Kuwait City'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_126',
    name: 'Bahrain',
    states: [
      ZoneState(
        id: 'state_w_126_1',
        name: 'Bahrain Cities',
        cities: [
          ZoneCity(id: 'city_w_126_1_1', name: 'Bahrain'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_127',
    name: 'Yemen',
    states: [
      ZoneState(
        id: 'state_w_127_1',
        name: 'Yemen Cities',
        cities: [
          ZoneCity(id: 'city_w_127_1_1', name: 'Aden'),
          ZoneCity(id: 'city_w_127_1_2', name: 'Aden'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_128',
    name: 'Iraq',
    states: [
      ZoneState(
        id: 'state_w_128_1',
        name: 'Iraq Cities',
        cities: [
          ZoneCity(id: 'city_w_128_1_1', name: 'Baghdad'),
          ZoneCity(id: 'city_w_128_1_2', name: 'Basra'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_129',
    name: 'Iran',
    states: [
      ZoneState(
        id: 'state_w_129_1',
        name: 'Iran Cities',
        cities: [
          ZoneCity(id: 'city_w_129_1_1', name: 'Tehran'),
          ZoneCity(id: 'city_w_129_1_2', name: 'Bandar Abbas'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_130',
    name: 'Turkey',
    states: [
      ZoneState(
        id: 'state_w_130_1',
        name: 'Turkey Cities',
        cities: [
          ZoneCity(id: 'city_w_130_1_1', name: 'Istanbul'),
          ZoneCity(id: 'city_w_130_1_2', name: 'Ankara'),
          ZoneCity(id: 'city_w_130_1_3', name: 'Izmir'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_131',
    name: 'Lebanon',
    states: [
      ZoneState(
        id: 'state_w_131_1',
        name: 'Lebanon Cities',
        cities: [
          ZoneCity(id: 'city_w_131_1_1', name: 'Beirut'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_132',
    name: 'Israel',
    states: [
      ZoneState(
        id: 'state_w_132_1',
        name: 'Israel Cities',
        cities: [
          ZoneCity(id: 'city_w_132_1_1', name: 'Tel Aviv'),
          ZoneCity(id: 'city_w_132_1_2', name: 'Haifa'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_133',
    name: 'Jordan',
    states: [
      ZoneState(
        id: 'state_w_133_1',
        name: 'Jordan Cities',
        cities: [
          ZoneCity(id: 'city_w_133_1_1', name: 'Amman'),
          ZoneCity(id: 'city_w_133_1_2', name: 'Aqaba'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_134',
    name: 'Syria',
    states: [
      ZoneState(
        id: 'state_w_134_1',
        name: 'Syria Cities',
        cities: [
          ZoneCity(id: 'city_w_134_1_1', name: 'Damascus'),
          ZoneCity(id: 'city_w_134_1_2', name: 'Latakia'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_135',
    name: 'Cyprus',
    states: [
      ZoneState(
        id: 'state_w_135_1',
        name: 'Cyprus Cities',
        cities: [
          ZoneCity(id: 'city_w_135_1_1', name: 'Nicosia'),
          ZoneCity(id: 'city_w_135_1_2', name: 'Limassol'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_136',
    name: 'Georgia',
    states: [
      ZoneState(
        id: 'state_w_136_1',
        name: 'Georgia Cities',
        cities: [
          ZoneCity(id: 'city_w_136_1_1', name: 'Tbilisi'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_137',
    name: 'Armenia',
    states: [
      ZoneState(
        id: 'state_w_137_1',
        name: 'Armenia Cities',
        cities: [
          ZoneCity(id: 'city_w_137_1_1', name: 'Yerevan'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_138',
    name: 'Azerbaijan',
    states: [
      ZoneState(
        id: 'state_w_138_1',
        name: 'Azerbaijan Cities',
        cities: [
          ZoneCity(id: 'city_w_138_1_1', name: 'Baku'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_139',
    name: 'Uzbekistan',
    states: [
      ZoneState(
        id: 'state_w_139_1',
        name: 'Uzbekistan Cities',
        cities: [
          ZoneCity(id: 'city_w_139_1_1', name: 'Tashkent'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_140',
    name: 'Kazakhstan',
    states: [
      ZoneState(
        id: 'state_w_140_1',
        name: 'Kazakhstan Cities',
        cities: [
          ZoneCity(id: 'city_w_140_1_1', name: 'Almaty'),
          ZoneCity(id: 'city_w_140_1_2', name: 'Nur-Sultan'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_141',
    name: 'Kyrgyzstan',
    states: [
      ZoneState(
        id: 'state_w_141_1',
        name: 'Kyrgyzstan Cities',
        cities: [
          ZoneCity(id: 'city_w_141_1_1', name: 'Bishkek'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_142',
    name: 'Tajikistan',
    states: [
      ZoneState(
        id: 'state_w_142_1',
        name: 'Tajikistan Cities',
        cities: [
          ZoneCity(id: 'city_w_142_1_1', name: 'Dushanbe'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_143',
    name: 'Turkmenistan',
    states: [
      ZoneState(
        id: 'state_w_143_1',
        name: 'Turkmenistan Cities',
        cities: [
          ZoneCity(id: 'city_w_143_1_1', name: 'Ashgabat'),
          ZoneCity(id: 'city_w_143_1_2', name: 'Turkmenbashi'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_144',
    name: 'UK',
    states: [
      ZoneState(
        id: 'state_w_144_1',
        name: 'UK Cities',
        cities: [
          ZoneCity(id: 'city_w_144_1_1', name: 'London'),
          ZoneCity(id: 'city_w_144_1_2', name: 'Felixstowe'),
          ZoneCity(id: 'city_w_144_1_3', name: 'Southampton'),
          ZoneCity(id: 'city_w_144_1_4', name: 'Liverpool'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_145',
    name: 'France',
    states: [
      ZoneState(
        id: 'state_w_145_1',
        name: 'France Cities',
        cities: [
          ZoneCity(id: 'city_w_145_1_1', name: 'Paris'),
          ZoneCity(id: 'city_w_145_1_2', name: 'Marseille'),
          ZoneCity(id: 'city_w_145_1_3', name: 'Le Havre'),
          ZoneCity(id: 'city_w_145_1_4', name: 'Lyon'),
          ZoneCity(id: 'city_w_145_1_5', name: 'Reunion'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_146',
    name: 'Netherlands',
    states: [
      ZoneState(
        id: 'state_w_146_1',
        name: 'Netherlands Cities',
        cities: [
          ZoneCity(id: 'city_w_146_1_1', name: 'Rotterdam'),
          ZoneCity(id: 'city_w_146_1_2', name: 'Amsterdam'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_147',
    name: 'Belgium',
    states: [
      ZoneState(
        id: 'state_w_147_1',
        name: 'Belgium Cities',
        cities: [
          ZoneCity(id: 'city_w_147_1_1', name: 'Antwerp'),
          ZoneCity(id: 'city_w_147_1_2', name: 'Brussels'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_148',
    name: 'Germany',
    states: [
      ZoneState(
        id: 'state_w_148_1',
        name: 'Germany Cities',
        cities: [
          ZoneCity(id: 'city_w_148_1_1', name: 'Hamburg'),
          ZoneCity(id: 'city_w_148_1_2', name: 'Frankfurt'),
          ZoneCity(id: 'city_w_148_1_3', name: 'Munich'),
          ZoneCity(id: 'city_w_148_1_4', name: 'Berlin'),
          ZoneCity(id: 'city_w_148_1_5', name: 'Bremen'),
          ZoneCity(id: 'city_w_148_1_6', name: 'Duisburg'),
          ZoneCity(id: 'city_w_148_1_7', name: 'Cologne'),
          ZoneCity(id: 'city_w_148_1_8', name: 'Düsseldorf'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_149',
    name: 'Switzerland',
    states: [
      ZoneState(
        id: 'state_w_149_1',
        name: 'Switzerland Cities',
        cities: [
          ZoneCity(id: 'city_w_149_1_1', name: 'Zurich'),
          ZoneCity(id: 'city_w_149_1_2', name: 'Geneva'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_150',
    name: 'Austria',
    states: [
      ZoneState(
        id: 'state_w_150_1',
        name: 'Austria Cities',
        cities: [
          ZoneCity(id: 'city_w_150_1_1', name: 'Vienna'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_151',
    name: 'Spain',
    states: [
      ZoneState(
        id: 'state_w_151_1',
        name: 'Spain Cities',
        cities: [
          ZoneCity(id: 'city_w_151_1_1', name: 'Madrid'),
          ZoneCity(id: 'city_w_151_1_2', name: 'Barcelona'),
          ZoneCity(id: 'city_w_151_1_3', name: 'Valencia'),
          ZoneCity(id: 'city_w_151_1_4', name: 'Bilbao'),
          ZoneCity(id: 'city_w_151_1_5', name: 'Algeciras'),
          ZoneCity(id: 'city_w_151_1_6', name: 'Algeciras'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_152',
    name: 'Portugal',
    states: [
      ZoneState(
        id: 'state_w_152_1',
        name: 'Portugal Cities',
        cities: [
          ZoneCity(id: 'city_w_152_1_1', name: 'Lisbon'),
          ZoneCity(id: 'city_w_152_1_2', name: 'Sines'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_153',
    name: 'Italy',
    states: [
      ZoneState(
        id: 'state_w_153_1',
        name: 'Italy Cities',
        cities: [
          ZoneCity(id: 'city_w_153_1_1', name: 'Rome'),
          ZoneCity(id: 'city_w_153_1_2', name: 'Milan'),
          ZoneCity(id: 'city_w_153_1_3', name: 'Genoa'),
          ZoneCity(id: 'city_w_153_1_4', name: 'Naples'),
          ZoneCity(id: 'city_w_153_1_5', name: 'Venice'),
          ZoneCity(id: 'city_w_153_1_6', name: 'Trieste'),
          ZoneCity(id: 'city_w_153_1_7', name: 'Gioia Tauro'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_154',
    name: 'Greece',
    states: [
      ZoneState(
        id: 'state_w_154_1',
        name: 'Greece Cities',
        cities: [
          ZoneCity(id: 'city_w_154_1_1', name: 'Athens'),
          ZoneCity(id: 'city_w_154_1_2', name: 'Piraeus'),
          ZoneCity(id: 'city_w_154_1_3', name: 'Thessaloniki'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_155',
    name: 'Sweden',
    states: [
      ZoneState(
        id: 'state_w_155_1',
        name: 'Sweden Cities',
        cities: [
          ZoneCity(id: 'city_w_155_1_1', name: 'Stockholm'),
          ZoneCity(id: 'city_w_155_1_2', name: 'Gothenburg'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_156',
    name: 'Norway',
    states: [
      ZoneState(
        id: 'state_w_156_1',
        name: 'Norway Cities',
        cities: [
          ZoneCity(id: 'city_w_156_1_1', name: 'Oslo'),
          ZoneCity(id: 'city_w_156_1_2', name: 'Bergen'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_157',
    name: 'Denmark',
    states: [
      ZoneState(
        id: 'state_w_157_1',
        name: 'Denmark Cities',
        cities: [
          ZoneCity(id: 'city_w_157_1_1', name: 'Copenhagen'),
          ZoneCity(id: 'city_w_157_1_2', name: 'Aarhus'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_158',
    name: 'Finland',
    states: [
      ZoneState(
        id: 'state_w_158_1',
        name: 'Finland Cities',
        cities: [
          ZoneCity(id: 'city_w_158_1_1', name: 'Helsinki'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_159',
    name: 'Russia',
    states: [
      ZoneState(
        id: 'state_w_159_1',
        name: 'Russia Cities',
        cities: [
          ZoneCity(id: 'city_w_159_1_1', name: 'Moscow'),
          ZoneCity(id: 'city_w_159_1_2', name: 'St Petersburg'),
          ZoneCity(id: 'city_w_159_1_3', name: 'Novosibirsk'),
          ZoneCity(id: 'city_w_159_1_4', name: 'Vladivostok'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_160',
    name: 'Poland',
    states: [
      ZoneState(
        id: 'state_w_160_1',
        name: 'Poland Cities',
        cities: [
          ZoneCity(id: 'city_w_160_1_1', name: 'Warsaw'),
          ZoneCity(id: 'city_w_160_1_2', name: 'Gdansk'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_161',
    name: 'Czech Republic',
    states: [
      ZoneState(
        id: 'state_w_161_1',
        name: 'Czech Republic Cities',
        cities: [
          ZoneCity(id: 'city_w_161_1_1', name: 'Prague'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_162',
    name: 'Hungary',
    states: [
      ZoneState(
        id: 'state_w_162_1',
        name: 'Hungary Cities',
        cities: [
          ZoneCity(id: 'city_w_162_1_1', name: 'Budapest'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_163',
    name: 'Romania',
    states: [
      ZoneState(
        id: 'state_w_163_1',
        name: 'Romania Cities',
        cities: [
          ZoneCity(id: 'city_w_163_1_1', name: 'Bucharest'),
          ZoneCity(id: 'city_w_163_1_2', name: 'Constanta'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_164',
    name: 'Egypt',
    states: [
      ZoneState(
        id: 'state_w_164_1',
        name: 'Egypt Cities',
        cities: [
          ZoneCity(id: 'city_w_164_1_1', name: 'Cairo'),
          ZoneCity(id: 'city_w_164_1_2', name: 'Alexandria'),
          ZoneCity(id: 'city_w_164_1_3', name: 'Port Said'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_165',
    name: 'Morocco',
    states: [
      ZoneState(
        id: 'state_w_165_1',
        name: 'Morocco Cities',
        cities: [
          ZoneCity(id: 'city_w_165_1_1', name: 'Casablanca'),
          ZoneCity(id: 'city_w_165_1_2', name: 'Tanger Med'),
          ZoneCity(id: 'city_w_165_1_3', name: 'Tanger Med'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_166',
    name: 'Algeria',
    states: [
      ZoneState(
        id: 'state_w_166_1',
        name: 'Algeria Cities',
        cities: [
          ZoneCity(id: 'city_w_166_1_1', name: 'Algiers'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_167',
    name: 'Tunisia',
    states: [
      ZoneState(
        id: 'state_w_167_1',
        name: 'Tunisia Cities',
        cities: [
          ZoneCity(id: 'city_w_167_1_1', name: 'Tunis'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_168',
    name: 'South Africa',
    states: [
      ZoneState(
        id: 'state_w_168_1',
        name: 'South Africa Cities',
        cities: [
          ZoneCity(id: 'city_w_168_1_1', name: 'Cape Town'),
          ZoneCity(id: 'city_w_168_1_2', name: 'Durban'),
          ZoneCity(id: 'city_w_168_1_3', name: 'Johannesburg'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_169',
    name: 'Nigeria',
    states: [
      ZoneState(
        id: 'state_w_169_1',
        name: 'Nigeria Cities',
        cities: [
          ZoneCity(id: 'city_w_169_1_1', name: 'Lagos'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_170',
    name: 'Kenya',
    states: [
      ZoneState(
        id: 'state_w_170_1',
        name: 'Kenya Cities',
        cities: [
          ZoneCity(id: 'city_w_170_1_1', name: 'Mombasa'),
          ZoneCity(id: 'city_w_170_1_2', name: 'Nairobi'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_171',
    name: 'Tanzania',
    states: [
      ZoneState(
        id: 'state_w_171_1',
        name: 'Tanzania Cities',
        cities: [
          ZoneCity(id: 'city_w_171_1_1', name: 'Dar es Salaam'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_172',
    name: 'Ethiopia',
    states: [
      ZoneState(
        id: 'state_w_172_1',
        name: 'Ethiopia Cities',
        cities: [
          ZoneCity(id: 'city_w_172_1_1', name: 'Addis Ababa'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_173',
    name: 'Ghana',
    states: [
      ZoneState(
        id: 'state_w_173_1',
        name: 'Ghana Cities',
        cities: [
          ZoneCity(id: 'city_w_173_1_1', name: 'Tema'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_174',
    name: 'Senegal',
    states: [
      ZoneState(
        id: 'state_w_174_1',
        name: 'Senegal Cities',
        cities: [
          ZoneCity(id: 'city_w_174_1_1', name: 'Dakar'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_175',
    name: 'Cote d\'Ivoire',
    states: [
      ZoneState(
        id: 'state_w_175_1',
        name: "Cote d'Ivoire Cities",
        cities: [
          ZoneCity(id: 'city_w_175_1_1', name: 'Abidjan'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_176',
    name: 'Namibia',
    states: [
      ZoneState(
        id: 'state_w_176_1',
        name: 'Namibia Cities',
        cities: [
          ZoneCity(id: 'city_w_176_1_1', name: 'Walvis Bay'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_177',
    name: 'Angola',
    states: [
      ZoneState(
        id: 'state_w_177_1',
        name: 'Angola Cities',
        cities: [
          ZoneCity(id: 'city_w_177_1_1', name: 'Luanda'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_178',
    name: 'Djibouti',
    states: [
      ZoneState(
        id: 'state_w_178_1',
        name: 'Djibouti Cities',
        cities: [
          ZoneCity(id: 'city_w_178_1_1', name: 'Djibouti'),
          ZoneCity(id: 'city_w_178_1_2', name: 'Djibouti'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_179',
    name: 'Madagascar',
    states: [
      ZoneState(
        id: 'state_w_179_1',
        name: 'Madagascar Cities',
        cities: [
          ZoneCity(id: 'city_w_179_1_1', name: 'Toamasina'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_180',
    name: 'New Caledonia',
    states: [
      ZoneState(
        id: 'state_w_180_1',
        name: 'New Caledonia Cities',
        cities: [
          ZoneCity(id: 'city_w_180_1_1', name: 'Noumea'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_181',
    name: 'USA',
    states: [
      ZoneState(
        id: 'state_w_181_1',
        name: 'USA Cities',
        cities: [
          ZoneCity(id: 'city_w_181_1_1', name: 'New York'),
          ZoneCity(id: 'city_w_181_1_2', name: 'Los Angeles'),
          ZoneCity(id: 'city_w_181_1_3', name: 'Chicago'),
          ZoneCity(id: 'city_w_181_1_4', name: 'Houston'),
          ZoneCity(id: 'city_w_181_1_5', name: 'Miami'),
          ZoneCity(id: 'city_w_181_1_6', name: 'New Orleans'),
          ZoneCity(id: 'city_w_181_1_7', name: 'Seattle'),
          ZoneCity(id: 'city_w_181_1_8', name: 'San Francisco'),
          ZoneCity(id: 'city_w_181_1_9', name: 'Long Beach'),
          ZoneCity(id: 'city_w_181_1_10', name: 'Baltimore'),
          ZoneCity(id: 'city_w_181_1_11', name: 'Norfolk'),
          ZoneCity(id: 'city_w_181_1_12', name: 'Savannah'),
          ZoneCity(id: 'city_w_181_1_13', name: 'Jacksonville'),
          ZoneCity(id: 'city_w_181_1_14', name: 'Atlanta'),
          ZoneCity(id: 'city_w_181_1_15', name: 'Dallas'),
          ZoneCity(id: 'city_w_181_1_16', name: 'Phoenix'),
          ZoneCity(id: 'city_w_181_1_17', name: 'Denver'),
          ZoneCity(id: 'city_w_181_1_18', name: 'Minneapolis'),
          ZoneCity(id: 'city_w_181_1_19', name: 'Detroit'),
          ZoneCity(id: 'city_w_181_1_20', name: 'Washington DC'),
          ZoneCity(id: 'city_w_181_1_21', name: 'Boston'),
          ZoneCity(id: 'city_w_181_1_22', name: 'Portland'),
          ZoneCity(id: 'city_w_181_1_23', name: 'Anchorage'),
          ZoneCity(id: 'city_w_181_1_24', name: 'Honolulu'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_182',
    name: 'Canada',
    states: [
      ZoneState(
        id: 'state_w_182_1',
        name: 'Canada Cities',
        cities: [
          ZoneCity(id: 'city_w_182_1_1', name: 'Toronto'),
          ZoneCity(id: 'city_w_182_1_2', name: 'Vancouver'),
          ZoneCity(id: 'city_w_182_1_3', name: 'Montreal'),
          ZoneCity(id: 'city_w_182_1_4', name: 'Halifax'),
          ZoneCity(id: 'city_w_182_1_5', name: 'Calgary'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_183',
    name: 'Mexico',
    states: [
      ZoneState(
        id: 'state_w_183_1',
        name: 'Mexico Cities',
        cities: [
          ZoneCity(id: 'city_w_183_1_1', name: 'Mexico City'),
          ZoneCity(id: 'city_w_183_1_2', name: 'Veracruz'),
          ZoneCity(id: 'city_w_183_1_3', name: 'Manzanillo'),
          ZoneCity(id: 'city_w_183_1_4', name: 'Guadalajara'),
          ZoneCity(id: 'city_w_183_1_5', name: 'Monterrey'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_184',
    name: 'Panama',
    states: [
      ZoneState(
        id: 'state_w_184_1',
        name: 'Panama Cities',
        cities: [
          ZoneCity(id: 'city_w_184_1_1', name: 'Panama City'),
          ZoneCity(id: 'city_w_184_1_2', name: 'Colón'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_185',
    name: 'Cuba',
    states: [
      ZoneState(
        id: 'state_w_185_1',
        name: 'Cuba Cities',
        cities: [
          ZoneCity(id: 'city_w_185_1_1', name: 'Havana'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_186',
    name: 'Dominican Republic',
    states: [
      ZoneState(
        id: 'state_w_186_1',
        name: 'Dominican Republic Cities',
        cities: [
          ZoneCity(id: 'city_w_186_1_1', name: 'Santo Domingo'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_187',
    name: 'Jamaica',
    states: [
      ZoneState(
        id: 'state_w_187_1',
        name: 'Jamaica Cities',
        cities: [
          ZoneCity(id: 'city_w_187_1_1', name: 'Kingston'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_188',
    name: 'Costa Rica',
    states: [
      ZoneState(
        id: 'state_w_188_1',
        name: 'Costa Rica Cities',
        cities: [
          ZoneCity(id: 'city_w_188_1_1', name: 'San José'),
          ZoneCity(id: 'city_w_188_1_2', name: 'Puerto Limón'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_189',
    name: 'Guatemala',
    states: [
      ZoneState(
        id: 'state_w_189_1',
        name: 'Guatemala Cities',
        cities: [
          ZoneCity(id: 'city_w_189_1_1', name: 'Guatemala City'),
          ZoneCity(id: 'city_w_189_1_2', name: 'Puerto Quetzal'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_190',
    name: 'Honduras',
    states: [
      ZoneState(
        id: 'state_w_190_1',
        name: 'Honduras Cities',
        cities: [
          ZoneCity(id: 'city_w_190_1_1', name: 'Tegucigalpa'),
          ZoneCity(id: 'city_w_190_1_2', name: 'Puerto Cortés'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_191',
    name: 'Nicaragua',
    states: [
      ZoneState(
        id: 'state_w_191_1',
        name: 'Nicaragua Cities',
        cities: [
          ZoneCity(id: 'city_w_191_1_1', name: 'Managua'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_192',
    name: 'Brazil',
    states: [
      ZoneState(
        id: 'state_w_192_1',
        name: 'Brazil Cities',
        cities: [
          ZoneCity(id: 'city_w_192_1_1', name: 'São Paulo'),
          ZoneCity(id: 'city_w_192_1_2', name: 'Rio de Janeiro'),
          ZoneCity(id: 'city_w_192_1_3', name: 'Santos'),
          ZoneCity(id: 'city_w_192_1_4', name: 'Itajaí'),
          ZoneCity(id: 'city_w_192_1_5', name: 'Manaus'),
          ZoneCity(id: 'city_w_192_1_6', name: 'Belém'),
          ZoneCity(id: 'city_w_192_1_7', name: 'Fortaleza'),
          ZoneCity(id: 'city_w_192_1_8', name: 'Salvador'),
          ZoneCity(id: 'city_w_192_1_9', name: 'Recife'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_193',
    name: 'Argentina',
    states: [
      ZoneState(
        id: 'state_w_193_1',
        name: 'Argentina Cities',
        cities: [
          ZoneCity(id: 'city_w_193_1_1', name: 'Buenos Aires'),
          ZoneCity(id: 'city_w_193_1_2', name: 'Córdoba'),
          ZoneCity(id: 'city_w_193_1_3', name: 'Rosario'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_194',
    name: 'Chile',
    states: [
      ZoneState(
        id: 'state_w_194_1',
        name: 'Chile Cities',
        cities: [
          ZoneCity(id: 'city_w_194_1_1', name: 'Santiago'),
          ZoneCity(id: 'city_w_194_1_2', name: 'Valparaíso'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_195',
    name: 'Peru',
    states: [
      ZoneState(
        id: 'state_w_195_1',
        name: 'Peru Cities',
        cities: [
          ZoneCity(id: 'city_w_195_1_1', name: 'Lima'),
          ZoneCity(id: 'city_w_195_1_2', name: 'Callao'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_196',
    name: 'Colombia',
    states: [
      ZoneState(
        id: 'state_w_196_1',
        name: 'Colombia Cities',
        cities: [
          ZoneCity(id: 'city_w_196_1_1', name: 'Bogotá'),
          ZoneCity(id: 'city_w_196_1_2', name: 'Cartagena'),
          ZoneCity(id: 'city_w_196_1_3', name: 'Barranquilla'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_197',
    name: 'Venezuela',
    states: [
      ZoneState(
        id: 'state_w_197_1',
        name: 'Venezuela Cities',
        cities: [
          ZoneCity(id: 'city_w_197_1_1', name: 'Caracas'),
          ZoneCity(id: 'city_w_197_1_2', name: 'La Guaira'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_198',
    name: 'Ecuador',
    states: [
      ZoneState(
        id: 'state_w_198_1',
        name: 'Ecuador Cities',
        cities: [
          ZoneCity(id: 'city_w_198_1_1', name: 'Quito'),
          ZoneCity(id: 'city_w_198_1_2', name: 'Guayaquil'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_199',
    name: 'Bolivia',
    states: [
      ZoneState(
        id: 'state_w_199_1',
        name: 'Bolivia Cities',
        cities: [
          ZoneCity(id: 'city_w_199_1_1', name: 'La Paz'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_200',
    name: 'Paraguay',
    states: [
      ZoneState(
        id: 'state_w_200_1',
        name: 'Paraguay Cities',
        cities: [
          ZoneCity(id: 'country_w_200_1_1', name: 'Asunción'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_201',
    name: 'Uruguay',
    states: [
      ZoneState(
        id: 'state_w_201_1',
        name: 'Uruguay Cities',
        cities: [
          ZoneCity(id: 'city_w_201_1_1', name: 'Montevideo'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_202',
    name: 'Guyana',
    states: [
      ZoneState(
        id: 'state_w_202_1',
        name: 'Guyana Cities',
        cities: [
          ZoneCity(id: 'city_w_202_1_1', name: 'Georgetown'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_203',
    name: 'Suriname',
    states: [
      ZoneState(
        id: 'state_w_203_1',
        name: 'Suriname Cities',
        cities: [
          ZoneCity(id: 'city_w_203_1_1', name: 'Paramaribo'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_204',
    name: 'French Guiana',
    states: [
      ZoneState(
        id: 'state_w_204_1',
        name: 'French Guiana Cities',
        cities: [
          ZoneCity(id: 'city_w_204_1_1', name: 'Cayenne'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_205',
    name: 'Australia',
    states: [
      ZoneState(
        id: 'state_w_205_1',
        name: 'Australia Cities',
        cities: [
          ZoneCity(id: 'city_w_205_1_1', name: 'Sydney'),
          ZoneCity(id: 'city_w_205_1_2', name: 'Melbourne'),
          ZoneCity(id: 'city_w_205_1_3', name: 'Brisbane'),
          ZoneCity(id: 'city_w_205_1_4', name: 'Perth'),
          ZoneCity(id: 'city_w_205_1_5', name: 'Adelaide'),
          ZoneCity(id: 'city_w_205_1_6', name: 'Port Hedland'),
          ZoneCity(id: 'city_w_205_1_7', name: 'Gladstone'),
          ZoneCity(id: 'city_w_205_1_8', name: 'Fremantle'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_206',
    name: 'New Zealand',
    states: [
      ZoneState(
        id: 'state_w_206_1',
        name: 'New Zealand Cities',
        cities: [
          ZoneCity(id: 'city_w_206_1_1', name: 'Auckland'),
          ZoneCity(id: 'city_w_206_1_2', name: 'Wellington'),
          ZoneCity(id: 'city_w_206_1_3', name: 'Christchurch'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_207',
    name: 'Fiji',
    states: [
      ZoneState(
        id: 'state_w_207_1',
        name: 'Fiji Cities',
        cities: [
          ZoneCity(id: 'city_w_207_1_1', name: 'Suva'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_208',
    name: 'Papua New Guinea',
    states: [
      ZoneState(
        id: 'state_w_208_1',
        name: 'Papua New Guinea Cities',
        cities: [
          ZoneCity(id: 'city_w_208_1_1', name: 'Port Moresby'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_209',
    name: 'Solomon Islands',
    states: [
      ZoneState(
        id: 'state_w_209_1',
        name: 'Solomon Islands Cities',
        cities: [
          ZoneCity(id: 'city_w_209_1_1', name: 'Honiara'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_210',
    name: 'Tonga',
    states: [
      ZoneState(
        id: 'state_w_210_1',
        name: 'Tonga Cities',
        cities: [
          ZoneCity(id: 'city_w_210_1_1', name: "Nuku'alofa"),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_211',
    name: 'Samoa',
    states: [
      ZoneState(
        id: 'state_w_211_1',
        name: 'Samoa Cities',
        cities: [
          ZoneCity(id: 'city_w_211_1_1', name: 'Apia'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_212',
    name: 'Guam',
    states: [
      ZoneState(
        id: 'state_w_212_1',
        name: 'Guam Cities',
        cities: [
          ZoneCity(id: 'city_w_212_1_1', name: 'Guam'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_213',
    name: 'Mauritius',
    states: [
      ZoneState(
        id: 'state_w_213_1',
        name: 'Mauritius Cities',
        cities: [
          ZoneCity(id: 'city_w_213_1_1', name: 'Port Louis'),
        ],
      ),
    ],
  ),
  ZoneCountry(
    id: 'country_w_214',
    name: 'Taiwan',
    states: [
      ZoneState(
        id: 'state_w_214_1',
        name: 'Taiwan Cities',
        cities: [
          ZoneCity(id: 'city_w_214_1_1', name: 'Kaohsiung'),
          ZoneCity(id: 'city_w_214_1_2', name: 'Taipei'),
          ZoneCity(id: 'city_w_214_1_3', name: 'Taichung'),
          ZoneCity(id: 'city_w_214_1_4', name: 'Keelung'),
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

List<String> getAllCityNames() {
  final List<String> names = [];
  for (var country in mockDeliveryData) {
    for (var state in country.states) {
      for (var city in state.cities) {
        names.add("${city.name}, ${country.name}");
      }
    }
  }
  return names;
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
                if (constraints.maxWidth > 450) {
                  return SizedBox(
                    height: 250,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildStateList(theme, accentColor)),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: _buildCityList(theme, accentColor)),
                      ],
                    ),
                  );
                } else {
                  return Column(
                    children: [
                      SizedBox(height: 200, child: _buildStateList(theme, accentColor)),
                      const SizedBox(height: 16),
                      SizedBox(height: 200, child: _buildCityList(theme, accentColor)),
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
              children: [
                Expanded(
                  child: Text(
                    'Tier 2: States',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text('All', style: theme.textTheme.bodySmall),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: allStatesChecked,
                    onChanged: _toggleSelectAllStates,
                    activeColor: accentColor,
                  ),
                ),
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
                              children: [
                                Expanded(
                                  child: Text(
                                    state.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text('All', style: theme.textTheme.bodySmall),
                                Transform.scale(
                                  scale: 0.6,
                                  child: Switch(
                                    value: allCitiesInStateSelected,
                                    onChanged: (val) => _toggleAllCitiesForState(state.id, val),
                                    activeColor: accentColor,
                                  ),
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
