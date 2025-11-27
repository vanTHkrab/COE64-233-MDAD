import 'package:flutter/material.dart';
import 'package:flutter_basic/features/contact/presentation/widgets/contact_card.dart';
import 'package:flutter_basic/features/contact/data/contact.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          final email =
              '${contact.name.toLowerCase().split(' ')[0]}.${contact.name.toLowerCase().split(' ')[1].substring(0, 2)}@mail.wu.ac.th';

          return ContactCard(
            avatar: Image.asset(
              contact.avatar,
              fit: BoxFit.cover,
            ),
            name: contact.name,
            email: email,
            phone: contact.phone,
          );
        },
      ),
    );
  }
}
