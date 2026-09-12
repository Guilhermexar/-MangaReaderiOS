import SwiftUI

struct ContentView: View {
    @StateObject private var model = ReaderModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    ProgressView("Carregando capítulo…")
                } else if model.pages.isEmpty {
                    VStack(spacing: 18) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 48))
                        Text("Leitor de Mangá")
                            .font(.title2.bold())
                        Text("Cole a URL de um capítulo que você tem autorização para acessar.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        TextField("https://…", text: $model.urlText)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .textFieldStyle(.roundedBorder)
                        Button("Abrir capítulo") {
                            Task { await model.load(urlString: model.urlText) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ReaderView(model: model)
                }
            }
            .navigationTitle(model.title.isEmpty ? "Manga Reader" : model.title)
            .toolbar {
                if !model.pages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            model.showChapters.toggle()
                        } label: {
                            Image(systemName: "list.number")
                        }
                    }
                }
            }
            .sheet(isPresented: $model.showChapters) {
                ChapterPicker(model: model)
            }
        }
    }
}

struct ReaderView: View {
    @ObservedObject var model: ReaderModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.pages.enumerated()), id: \.offset) { index, pageURL in
                        AsyncImage(url: pageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                            case .failure:
                                VStack {
                                    Image(systemName: "exclamationmark.triangle")
                                    Text("Não foi possível carregar esta página.")
                                }
                                .frame(maxWidth: .infinity, minHeight: 300)
                            default:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 300)
                            }
                        }
                        .id(index)
                        .background(Color.black)
                        .onAppear {
                            model.saveProgress(page: index)
                        }
                    }

                    if let next = model.nextChapterURL {
                        VStack(spacing: 12) {
                            Text("Capítulo concluído")
                                .font(.headline)
                            Button("Próximo capítulo") {
                                Task { await model.load(url: next) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                    }
                }
            }
            .background(Color.black)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    model.goToPreviousPage()
                } label: { Image(systemName: "chevron.left") }

                Spacer()

                Text("\(model.currentPage + 1)/\(model.pages.count)")
                    .monospacedDigit()

                Spacer()

                Button {
                    model.goToNextPage()
                } label: { Image(systemName: "chevron.right") }
            }
        }
    }
}

struct ChapterPicker: View {
    @ObservedObject var model: ReaderModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(model.chapters) { chapter in
                Button {
                    dismiss()
                    Task { await model.load(url: chapter.url) }
                } label: {
                    HStack {
                        Text(chapter.name)
                        Spacer()
                        if chapter.url == model.currentURL {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            .navigationTitle("Capítulos")
        }
    }
}
