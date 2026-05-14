from pygrabber.dshow_graph import FilterGraph

def listar_dispositivos():
    graph = FilterGraph()
    dispositivos = graph.get_input_devices()
    
    print("\n=== CÂMERAS DETECTADAS NO WINDOWS ===")
    if not dispositivos:
        print("Nenhuma câmera encontrada.")
        return
        
    for index, name in enumerate(dispositivos):
        print(f"Índice: {index} -> Nome: {name}")
    print("=====================================\n")

if __name__ == "__main__":
    listar_dispositivos()