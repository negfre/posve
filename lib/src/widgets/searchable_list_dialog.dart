// --- Widget de Diálogo de Búsqueda Genérico ---

import 'package:flutter/material.dart';

class SearchableListDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final Widget Function(T item) itemBuilder; // Cómo construir cada item de la lista
  final bool Function(T item, String query) filterFn; // Cómo filtrar items basado en query
  final void Function(T item) onItemSelected; // Qué hacer cuando se selecciona un item

  const SearchableListDialog({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.filterFn,
    required this.onItemSelected,
  });

  @override
  State<SearchableListDialog<T>> createState() => _SearchableListDialogState<T>();
}

class _SearchableListDialogState<T> extends State<SearchableListDialog<T>> {
  String _searchQuery = '';
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    // Inicializar con todos los items o filtrar si hay query inicial (poco común)
    _filteredItems = widget.items;
    _filterItems(_searchQuery); // Aplicar filtro inicial (por si acaso)
  }

  void _filterItems(String query) {
    if (!mounted) return;
    setState(() {
      _searchQuery = query;
      if (_searchQuery.isEmpty) {
        _filteredItems = widget.items;
      } else {
        // Usar la función de filtro proporcionada
        _filteredItems = widget.items
            .where((item) => widget.filterFn(item, _searchQuery))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox( // Contenedor con tamaño limitado
        width: double.maxFinite, // Ocupar ancho disponible del diálogo
        // Limitar altura para evitar que ocupe toda la pantalla
        height: MediaQuery.of(context).size.height * 0.6, 
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Campo de búsqueda
            TextField(
              autofocus: true, // Enfocar automáticamente al abrir
              onChanged: _filterItems,
              decoration: const InputDecoration(
                labelText: 'Buscar...',
                hintText: 'Escriba para filtrar',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Lista de resultados filtrados
            Expanded(
              child: _filteredItems.isEmpty
                  ? const Center(child: Text('No se encontraron coincidencias.'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        // Devolver el widget construido por itemBuilder, envuelto en InkWell
                        return InkWell(
                           child: widget.itemBuilder(item),
                           onTap: () => widget.onItemSelected(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        // Botón para cerrar el diálogo
        TextButton(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(), // Devuelve null
        ),
      ],
    );
  }
} 