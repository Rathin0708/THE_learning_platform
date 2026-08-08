import 'package:llama_cpp_dart/llama_cpp_dart.dart';

void main() {
  Llama.libraryPath = r'D:\rath_tech_projects\THE\native\llama.cpp\build\bin\llama.dll';

  final llama = Llama(
    r'D:\rath_tech_projects\THE\native\models\qwen2.5-0.5b-instruct-q4_k_m.gguf',
    modelParams: ModelParams()
      ..nGpuLayers = 0
      ..mainGpu = -1,
    contextParams: ContextParams(),
    samplerParams: SamplerParams(),
    verbose: true,
  );

  llama.setPrompt(
    '<|im_start|>system\nYou are a helpful Tamil language tutor.<|im_end|>\n'
    '<|im_start|>user\nHow do you say "good morning" in Tamil? Answer in one short sentence.<|im_end|>\n'
    '<|im_start|>assistant\n',
  );

  final buffer = StringBuffer();
  var tokenCount = 0;
  while (true) {
    final (token, done) = llama.getNext();
    buffer.write(token);
    tokenCount++;
    if (done || tokenCount > 100) break;
  }

  print('===GENERATED===');
  print(buffer.toString());
  print('===TOKEN COUNT===');
  print(tokenCount);

  llama.dispose();
}
