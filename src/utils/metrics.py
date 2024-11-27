from torchmetrics import Accuracy, F1Score, AUROC
import torch
from typing import Any

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
from torchmetrics import F1Score, MetricCollection, Precision, Recall


def get_metrics(**kwargs: Any) -> MetricCollection:  # type: ignore  # Allow explicit `Any`
    return MetricCollection(
        {   'accuracy': Accuracy(**kwargs).to(device),
            'f1': F1Score(**kwargs).to(device),
            'precision': Precision(**kwargs).to(device),
            'recall': Recall(**kwargs).to(device),
        },
    )
