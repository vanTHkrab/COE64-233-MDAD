class Contact {
  final String avatar;
  final String name;
  final String phone;

  Contact({
    required this.name,
    required this.phone,
    this.avatar = 'assets/images/default_avatar.png',
  });
}

final List<Contact> contacts = [
  Contact(name: 'Audsadawut Nakthungtao', phone: '094-358-6014', avatar: "assets/images/van.jpg"),
  Contact(name: 'Mari-r Nithatnawadechakul ', phone: '987-654-3210', avatar: "assets/images/rr.jpg"),
  Contact(name: 'Aekkavee Bunnithinan', phone: '555-123-4567', avatar: "assets/images/akavee.jpg"),
];